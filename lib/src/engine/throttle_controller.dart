import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../model/endpoint_rule.dart';
import '../model/failure.dart';
import '../model/network_condition.dart';
import '../model/request_log.dart';
import '../model/response_tampering.dart';
import '../model/throttle_profile.dart';
import '../persistence/throttle_storage.dart';
import 'throttle_engine.dart';

/// Aggregate request statistics derived from the live log.
class ThrottleMetrics {
  /// Creates a metrics snapshot.
  const ThrottleMetrics({
    required this.total,
    required this.failed,
    required this.throttled,
    required this.averageAddedDelay,
  });

  /// Total captured entries.
  final int total;

  /// How many failed (dropped / timed out / injected error).
  final int failed;

  /// How many were slowed but completed.
  final int throttled;

  /// Mean artificial delay applied across throttled entries.
  final Duration averageAddedDelay;

  /// Failed as a fraction `0.0`–`1.0` of [total].
  double get failureRate => total == 0 ? 0 : failed / total;
}

/// The single source of truth for throttling state.
///
/// Holds the live [ThrottleProfile] and the captured request [log], exposes
/// mutators that the control-panel UI binds to, and owns the [ThrottleEngine]
/// that the HTTP / dio adapters consult. Being a [ChangeNotifier], any widget
/// can rebuild on changes via `ListenableBuilder` / `AnimatedBuilder`.
class ThrottleController extends ChangeNotifier {
  /// Creates a controller.
  ///
  /// [logCapacity] caps how many recent entries the live log retains. Pass
  /// [seed] to make the engine's jitter and failure rolls deterministic.
  ThrottleController({
    ThrottleProfile profile = ThrottleProfile.initial,
    int logCapacity = 50,
    int? seed,
    ThrottleStorage? storage,
  }) : _logCapacity = logCapacity < 1 ? 1 : logCapacity,
       _storage = storage,
       // ignore: prefer_initializing_formals
       _profile = profile {
    _engine = ThrottleEngine(
      profile: () => _profile,
      onLog: _appendLog,
      seed: seed,
    );
    loaded = storage == null ? Future<void>.value() : _restore();
  }

  ThrottleProfile _profile;
  final int _logCapacity;
  final ThrottleStorage? _storage;
  final List<RequestLogEntry> _log = <RequestLogEntry>[];
  final List<NetworkCondition> _customPresets = <NetworkCondition>[];
  late final ThrottleEngine _engine;
  bool _capturing = true;
  bool _saveScheduled = false;

  /// Completes once the initial state has been restored from [ThrottleStorage]
  /// (or immediately when no storage was provided). Await it if you need the
  /// restored configuration before building UI.
  late final Future<void> loaded;

  /// The current configuration.
  ThrottleProfile get profile => _profile;

  /// The engine the adapters route requests through.
  ThrottleEngine get engine => _engine;

  /// The captured request log, most-recent first (unmodifiable).
  List<RequestLogEntry> get log => List<RequestLogEntry>.unmodifiable(_log);

  /// Whether throttling is currently active.
  bool get enabled => _profile.enabled;

  /// The active network condition.
  NetworkCondition get condition => _profile.condition;

  /// The active failure-injection config.
  FailureInjection get failure => _profile.failure;

  /// The active response-tampering config.
  ResponseTampering get tampering => _profile.tampering;

  /// The active per-endpoint rules.
  List<EndpointRule> get rules => _profile.rules;

  /// The name of the active preset, or `'Custom'`.
  String get presetName => _profile.presetName;

  /// Whether new requests are being recorded into the live log.
  bool get capturing => _capturing;

  /// User-saved presets (via [saveCurrentAsPreset]), in insertion order.
  List<NetworkCondition> get customPresets =>
      List<NetworkCondition>.unmodifiable(_customPresets);

  /// All presets to surface as chips: the built-ins followed by saved ones.
  List<NetworkCondition> get presets => <NetworkCondition>[
    ...NetworkCondition.presets,
    ..._customPresets,
  ];

  /// Aggregate statistics derived from the current [log].
  ThrottleMetrics get metrics {
    var failed = 0;
    var throttled = 0;
    var delayMicros = 0;
    for (final entry in _log) {
      switch (entry.outcome) {
        case RequestOutcome.failed:
          failed++;
        case RequestOutcome.throttled:
          throttled++;
          delayMicros += entry.appliedDelay?.inMicroseconds ?? 0;
        case RequestOutcome.ok:
          delayMicros += entry.appliedDelay?.inMicroseconds ?? 0;
      }
    }
    return ThrottleMetrics(
      total: _log.length,
      failed: failed,
      throttled: throttled,
      averageAddedDelay: throttled == 0
          ? Duration.zero
          : Duration(microseconds: delayMicros ~/ throttled),
    );
  }

  /// A short human-readable summary for the panel header.
  String get statusLine {
    if (!_profile.enabled) return 'Paused · pass-through';
    final ms = _profile.condition.latency.inMilliseconds;
    final loss = (_profile.condition.packetLoss * 100).round();
    return '${_profile.presetName} · ${ms}ms · $loss% loss';
  }

  // --- master switch -------------------------------------------------------

  /// Enables or disables throttling.
  void setEnabled(bool value) => _set(_profile.copyWith(enabled: value));

  /// Flips the master switch.
  void toggleEnabled() => setEnabled(!_profile.enabled);

  // --- presets & conditions ------------------------------------------------

  /// Applies a named [preset], re-enabling throttling.
  void applyPreset(NetworkCondition preset) => _set(
    _profile.copyWith(
      condition: preset,
      presetName: preset.name,
      enabled: true,
    ),
  );

  /// Saves the current condition as a reusable preset named [name] and makes it
  /// the active preset. Replaces any existing custom preset with that name.
  void saveCurrentAsPreset(String name) {
    final preset = _profile.condition.copyWith(name: name);
    _customPresets.removeWhere((c) => c.name == name);
    _customPresets.add(preset);
    _set(_profile.copyWith(condition: preset, presetName: name));
  }

  /// Removes the saved preset named [name], if present.
  void deletePreset(String name) {
    final removed = _customPresets.length;
    _customPresets.removeWhere((c) => c.name == name);
    if (_customPresets.length != removed) {
      notifyListeners();
      _scheduleSave();
    }
  }

  /// Sets the connection-setup (DNS/TLS) delay, marking the profile `'Custom'`.
  void setConnectionSetup(Duration value) =>
      _setCustomCondition(_profile.condition.copyWith(connectionSetup: value));

  /// Sets the base latency, marking the profile as `'Custom'`.
  void setLatency(Duration value) =>
      _setCustomCondition(_profile.condition.copyWith(latency: value));

  /// Sets the latency jitter, marking the profile as `'Custom'`.
  void setJitter(Duration value) =>
      _setCustomCondition(_profile.condition.copyWith(latencyJitter: value));

  /// Sets how jitter is distributed, marking the profile as `'Custom'`.
  void setDistribution(LatencyDistribution value) =>
      _setCustomCondition(_profile.condition.copyWith(distribution: value));

  /// Sets the bandwidth cap in kbps, marking the profile as `'Custom'`.
  void setBandwidth(int kbps) =>
      _setCustomCondition(_profile.condition.copyWith(bandwidthKbps: kbps));

  /// Sets the packet-loss probability `0.0`–`1.0`, marking it `'Custom'`.
  void setPacketLoss(double value) =>
      _setCustomCondition(_profile.condition.copyWith(packetLoss: value));

  // --- failure injection ---------------------------------------------------

  /// Toggles failure injection on or off.
  void toggleFailure() => _set(
    _profile.copyWith(
      failure: _profile.failure.copyWith(enabled: !_profile.failure.enabled),
    ),
  );

  /// Selects the failure [type] to inject.
  void setFailureType(FailureType type) =>
      _set(_profile.copyWith(failure: _profile.failure.copyWith(type: type)));

  /// Sets the failure-injection probability `0.0`–`1.0`.
  void setFailureProbability(double value) => _set(
    _profile.copyWith(failure: _profile.failure.copyWith(probability: value)),
  );

  /// Sets the `Retry-After` delay advertised on injected 429 responses.
  void setRetryAfter(Duration value) => _set(
    _profile.copyWith(failure: _profile.failure.copyWith(retryAfter: value)),
  );

  // --- response tampering --------------------------------------------------

  /// Toggles response tampering on or off.
  void toggleTampering() => _set(
    _profile.copyWith(
      tampering: _profile.tampering.copyWith(
        enabled: !_profile.tampering.enabled,
      ),
    ),
  );

  /// Selects how a tampered response body is mangled.
  void setTamperMode(TamperMode mode) => _set(
    _profile.copyWith(tampering: _profile.tampering.copyWith(mode: mode)),
  );

  /// Sets the response-tampering probability `0.0`–`1.0`.
  void setTamperProbability(double value) => _set(
    _profile.copyWith(
      tampering: _profile.tampering.copyWith(probability: value),
    ),
  );

  // --- rules ---------------------------------------------------------------

  /// Appends a per-endpoint [rule].
  void addRule(EndpointRule rule) =>
      _set(_profile.copyWith(rules: <EndpointRule>[..._profile.rules, rule]));

  /// Replaces the rule at [index] with [rule].
  void updateRule(int index, EndpointRule rule) {
    final next = <EndpointRule>[..._profile.rules];
    next[index] = rule;
    _set(_profile.copyWith(rules: next));
  }

  /// Removes the rule at [index].
  void removeRule(int index) {
    final next = <EndpointRule>[..._profile.rules]..removeAt(index);
    _set(_profile.copyWith(rules: next));
  }

  // --- log -----------------------------------------------------------------

  /// Starts or stops recording requests into the live log. Throttling itself is
  /// unaffected — only capture pauses.
  void setCapturing(bool value) {
    if (_capturing == value) return;
    _capturing = value;
    notifyListeners();
  }

  /// Flips capture on/off.
  void toggleCapturing() => setCapturing(!_capturing);

  /// Clears the captured request log.
  void clearLog() {
    if (_log.isEmpty) return;
    _log.clear();
    notifyListeners();
  }

  /// Seeds the log with [entries] (most-recent first) — handy for previews.
  void seedLog(Iterable<RequestLogEntry> entries) {
    _log
      ..clear()
      ..addAll(entries.take(_logCapacity));
    notifyListeners();
  }

  void _appendLog(RequestLogEntry entry) {
    if (!_capturing) return;
    _log.insert(0, entry);
    if (_log.length > _logCapacity) {
      _log.removeRange(_logCapacity, _log.length);
    }
    notifyListeners();
  }

  void _setCustomCondition(NetworkCondition condition) => _set(
    _profile.copyWith(
      condition: condition.copyWith(name: 'Custom'),
      presetName: 'Custom',
    ),
  );

  void _set(ThrottleProfile profile) {
    _profile = profile;
    notifyListeners();
    _scheduleSave();
  }

  // --- persistence ---------------------------------------------------------

  /// Encodes the persistent state (profile + saved presets) as JSON.
  String encodeState() => jsonEncode(<String, dynamic>{
    'profile': _profile.toJson(),
    'presets': _customPresets.map((c) => c.toJson()).toList(),
  });

  Future<void> _restore() async {
    final storage = _storage;
    if (storage == null) return;
    final raw = await storage.read();
    if (raw == null) return;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      _profile = ThrottleProfile.fromJson(
        (map['profile'] as Map).cast<String, dynamic>(),
      );
      _customPresets
        ..clear()
        ..addAll(
          ((map['presets'] as List?) ?? const <dynamic>[]).map(
            (e) =>
                NetworkCondition.fromJson((e as Map).cast<String, dynamic>()),
          ),
        );
      notifyListeners();
    } catch (_) {
      // Ignore corrupt persisted state and start fresh.
    }
  }

  void _scheduleSave() {
    final storage = _storage;
    if (storage == null || _saveScheduled) return;
    _saveScheduled = true;
    scheduleMicrotask(() {
      _saveScheduled = false;
      storage.write(encodeState());
    });
  }
}
