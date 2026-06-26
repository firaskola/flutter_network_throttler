import 'dart:math';

import '../model/endpoint_rule.dart';
import '../model/failure.dart';
import '../model/network_condition.dart';
import '../model/request_log.dart';
import '../model/throttle_profile.dart';
import '../network_throttler.dart';

/// A failure the engine decided to apply to a request.
///
/// Carries enough information for an adapter to either throw a connection-level
/// error or synthesize an HTTP response with the right status code.
class EngineFailure {
  /// Creates an engine failure.
  const EngineFailure(this.type, this.reason);

  /// The kind of failure to produce.
  final FailureType type;

  /// Where the failure came from: `'packet loss'`, `'rule'`, or `'injection'`.
  final String reason;

  /// The HTTP status to synthesize, or `null` for connection-level failures.
  int? get httpStatus => type.httpStatus;

  /// Whether this failure has no HTTP response (timeout / dropped connection).
  bool get isConnectionLevel => type.httpStatus == null;
}

/// The decision the engine reached for a single request: how long to wait before
/// sending, whether to fail it, and whether to skip throttling entirely.
class EnginePlan {
  /// Creates an engine plan.
  const EnginePlan({
    required this.passThrough,
    required this.latency,
    required this.condition,
    this.failure,
    this.matchedRule,
  });

  /// When `true`, the request is sent untouched (throttling disabled or a
  /// pass-through rule matched).
  final bool passThrough;

  /// The delay to apply before sending (base latency + jitter + any rule delay).
  final Duration latency;

  /// The condition the plan was computed against.
  final NetworkCondition condition;

  /// The failure to apply instead of sending, or `null` to proceed normally.
  final EngineFailure? failure;

  /// The rule that matched this request, if any.
  final EndpointRule? matchedRule;
}

/// The adapter-agnostic decision core of the throttler.
///
/// Given the current [ThrottleProfile] (read lazily through a provider) it
/// decides, per request, how much latency to add, whether to drop or fail the
/// request, and how long bandwidth-limited transfers should take. It holds no
/// Flutter or HTTP dependencies so both the `http` and `dio` adapters can share
/// it.
class ThrottleEngine {
  /// Creates an engine.
  ///
  /// [profile] is read on every decision so the engine always sees the latest
  /// configuration. [onLog] receives captured request outcomes. Pass [seed] to
  /// make latency jitter and failure rolls deterministic in tests.
  ThrottleEngine({
    required ThrottleProfile Function() profile,
    required void Function(RequestLogEntry) onLog,
    int? seed,
  }) : _random = Random(seed),
       // ignore: prefer_initializing_formals
       _profile = profile,
       // ignore: prefer_initializing_formals
       _onLog = onLog;

  final ThrottleProfile Function() _profile;
  final void Function(RequestLogEntry) _onLog;
  final Random _random;

  /// Decides what to do with a request to [url] using [method].
  EnginePlan planRequest(String method, Uri url) {
    final profile = _profile();
    final condition = profile.condition;

    if (!profile.enabled) {
      return EnginePlan(
        passThrough: true,
        latency: Duration.zero,
        condition: condition,
      );
    }

    final matched = _firstMatchingRule(profile.rules, method, url);
    var latency = _latencyFor(condition);
    EngineFailure? failure;

    if (matched != null) {
      final action = matched.action;
      switch (action) {
        case PassThroughAction():
          return EnginePlan(
            passThrough: true,
            latency: Duration.zero,
            condition: condition,
            matchedRule: matched,
          );
        case DelayAction(:final extra):
          latency += extra;
        case FailAction(:final type):
          failure = EngineFailure(type, 'rule');
      }
    }

    // Connection-level packet loss.
    if (failure == null && _roll(condition.packetLoss)) {
      failure = const EngineFailure(FailureType.noConnection, 'packet loss');
    }

    // Probabilistic failure injection.
    if (failure == null &&
        profile.failure.enabled &&
        _roll(profile.failure.probability)) {
      failure = EngineFailure(profile.failure.type, 'injection');
    }

    return EnginePlan(
      passThrough: false,
      latency: latency,
      condition: condition,
      failure: failure,
      matchedRule: matched,
    );
  }

  /// The time a [bytes]-sized payload takes under the active bandwidth cap.
  Duration bandwidthDelay(int bytes, {bool upload = false}) {
    final condition = _profile().condition;
    final kbps = upload ? condition.uploadKbps : condition.downloadKbps;
    return NetworkThrottler.transferDuration(bytes, kbps);
  }

  /// Records a captured request outcome to the log sink.
  void record(RequestLogEntry entry) => _onLog(entry);

  EndpointRule? _firstMatchingRule(
    List<EndpointRule> rules,
    String method,
    Uri url,
  ) {
    for (final rule in rules) {
      if (rule.matches(method, url)) return rule;
    }
    return null;
  }

  Duration _latencyFor(NetworkCondition condition) {
    final jitterMicros = condition.latencyJitter.inMicroseconds;
    final extra = jitterMicros <= 0 ? 0 : _random.nextInt(jitterMicros + 1);
    return condition.latency + Duration(microseconds: extra);
  }

  bool _roll(double probability) {
    if (probability <= 0.0) return false;
    if (probability >= 1.0) return true;
    return _random.nextDouble() < probability;
  }
}
