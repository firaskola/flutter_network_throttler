import 'dart:math';

import 'package:meta/meta.dart';

/// How latency jitter is distributed around the base [NetworkCondition.latency].
///
/// Real networks rarely jitter uniformly: most requests cluster near a typical
/// value while a long tail of slow ones drags the average up. Picking a
/// distribution other than [uniform] makes simulated timings behave far more
/// like the real thing.
enum LatencyDistribution {
  /// Flat jitter: every value in `[0, jitter]` is equally likely (the classic,
  /// and the default for backwards compatibility).
  uniform,

  /// Bell-curve jitter centred in the middle of `[0, jitter]` — most requests
  /// land near the middle, few at the extremes.
  gaussian,

  /// Long-tailed jitter: most requests are quick, but a minority spike toward
  /// the top of `[0, jitter]`, mimicking real-world tail latency.
  longTail;

  /// A short label for UI controls.
  String get label {
    switch (this) {
      case LatencyDistribution.uniform:
        return 'Uniform';
      case LatencyDistribution.gaussian:
        return 'Gaussian';
      case LatencyDistribution.longTail:
        return 'Long-tail';
    }
  }
}

/// Describes a set of simulated network characteristics — connection-setup
/// overhead, latency, jitter, bandwidth, and packet loss — applied to throttled
/// traffic.
///
/// A condition is immutable. Build variations with [copyWith] or start from one
/// of the named presets such as [NetworkCondition.threeG].
///
/// Packet loss here models a *connection-level* drop (the request never
/// completes). It is deliberately separate from failure injection
/// (returning a specific HTTP status), which lives in `FailureInjection`.
@immutable
class NetworkCondition {
  /// Creates a network condition.
  ///
  /// [packetLoss] must be within the inclusive range `0.0` (never dropped) to
  /// `1.0` (always dropped). Bandwidth values are in kilobits per second, where
  /// `0` means unlimited. [connectionSetup] models the one-off DNS + TLS +
  /// connect cost paid before the request body is sent.
  const NetworkCondition({
    this.name = 'custom',
    this.connectionSetup = Duration.zero,
    this.latency = Duration.zero,
    this.latencyJitter = Duration.zero,
    this.distribution = LatencyDistribution.uniform,
    this.downloadKbps = 0,
    this.uploadKbps = 0,
    this.packetLoss = 0.0,
  }) : assert(
         packetLoss >= 0.0 && packetLoss <= 1.0,
         'packetLoss must be between 0.0 and 1.0',
       ),
       assert(downloadKbps >= 0, 'downloadKbps must be non-negative'),
       assert(uploadKbps >= 0, 'uploadKbps must be non-negative');

  /// Convenience constructor for a symmetric link where download and upload
  /// share a single [bandwidthKbps] cap — matching the control panel's single
  /// "Bandwidth cap" slider.
  const NetworkCondition.simple({
    String name = 'custom',
    Duration connectionSetup = Duration.zero,
    Duration latency = Duration.zero,
    Duration jitter = Duration.zero,
    LatencyDistribution distribution = LatencyDistribution.uniform,
    int bandwidthKbps = 0,
    double packetLoss = 0.0,
  }) : this(
         name: name,
         connectionSetup: connectionSetup,
         latency: latency,
         latencyJitter: jitter,
         distribution: distribution,
         downloadKbps: bandwidthKbps,
         uploadKbps: bandwidthKbps,
         packetLoss: packetLoss,
       );

  /// A human-readable label for this condition, e.g. `'3G'`.
  final String name;

  /// One-off connection-establishment cost (DNS lookup + TLS handshake +
  /// connect) paid before [latency] on every throttled request. Slow networks
  /// hurt most here, so it is modelled separately from per-request latency.
  final Duration connectionSetup;

  /// The base round-trip latency added before a request completes.
  final Duration latency;

  /// Random variation added to [latency], between `0` and this value, shaped by
  /// [distribution].
  final Duration latencyJitter;

  /// How [latencyJitter] is distributed around [latency].
  final LatencyDistribution distribution;

  /// Download throughput in kilobits per second (`0` = unlimited).
  final int downloadKbps;

  /// Upload throughput in kilobits per second (`0` = unlimited).
  final int uploadKbps;

  /// The probability in the range `0.0`–`1.0` that a request is dropped at the
  /// connection level (no response at all).
  final double packetLoss;

  /// The download bandwidth cap, surfaced as a single value for UI controls.
  int get bandwidthKbps => downloadKbps;

  /// Whether this condition represents a completely offline network.
  bool get isOffline => packetLoss >= 1.0;

  /// Samples the total pre-request delay for one request: [connectionSetup]
  /// plus [latency] plus a jitter draw shaped by [distribution].
  ///
  /// Pass a seeded [random] for deterministic results in tests.
  Duration sampleLatency(Random random) {
    final base = connectionSetup + latency;
    final jitterMicros = latencyJitter.inMicroseconds;
    if (jitterMicros <= 0) return base;
    final int extra;
    switch (distribution) {
      case LatencyDistribution.uniform:
        extra = random.nextInt(jitterMicros + 1);
      case LatencyDistribution.gaussian:
        extra = _gaussianDraw(random, jitterMicros);
      case LatencyDistribution.longTail:
        extra = _longTailDraw(random, jitterMicros);
    }
    return base + Duration(microseconds: extra);
  }

  // Box–Muller normal draw centred at the middle of [0, maxMicros]
  // (sd = maxMicros/4), clamped back into range.
  static int _gaussianDraw(Random random, int maxMicros) {
    final u1 = max(1e-9, random.nextDouble());
    final u2 = random.nextDouble();
    final z = sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
    final value = (maxMicros / 2) + z * (maxMicros / 4);
    return value.clamp(0.0, maxMicros.toDouble()).round();
  }

  // Cubed uniform: heavily biased toward small values, with an occasional spike
  // toward [maxMicros] — a simple bounded long tail.
  static int _longTailDraw(Random random, int maxMicros) {
    final u = random.nextDouble();
    return (maxMicros * u * u * u).round();
  }

  /// A pristine connection: no latency, no bandwidth cap, never drops.
  static const NetworkCondition perfect = NetworkCondition(name: 'perfect');

  /// Fast, stable broadband / Wi-Fi.
  static const NetworkCondition wifi = NetworkCondition.simple(
    name: 'WiFi',
    connectionSetup: Duration(milliseconds: 12),
    latency: Duration(milliseconds: 8),
    jitter: Duration(milliseconds: 4),
    bandwidthKbps: 30000,
  );

  /// A good 4G / LTE mobile connection.
  static const NetworkCondition fourG = NetworkCondition.simple(
    name: '4G',
    connectionSetup: Duration(milliseconds: 80),
    latency: Duration(milliseconds: 35),
    jitter: Duration(milliseconds: 15),
    bandwidthKbps: 9000,
    packetLoss: 0.01,
  );

  /// A typical 3G mobile connection.
  static const NetworkCondition threeG = NetworkCondition.simple(
    name: '3G',
    connectionSetup: Duration(milliseconds: 200),
    latency: Duration(milliseconds: 100),
    jitter: Duration(milliseconds: 40),
    distribution: LatencyDistribution.longTail,
    bandwidthKbps: 780,
    packetLoss: 0.03,
  );

  /// A slow, flaky 2G connection.
  static const NetworkCondition twoG = NetworkCondition.simple(
    name: '2G',
    connectionSetup: Duration(milliseconds: 550),
    latency: Duration(milliseconds: 650),
    jitter: Duration(milliseconds: 280),
    distribution: LatencyDistribution.longTail,
    bandwidthKbps: 60,
    packetLoss: 0.08,
  );

  /// A disconnected network where every request is dropped.
  static const NetworkCondition offline = NetworkCondition(
    name: 'Offline',
    packetLoss: 1.0,
  );

  /// The presets surfaced as chips in the control panel, fastest to slowest.
  static const List<NetworkCondition> presets = <NetworkCondition>[
    offline,
    twoG,
    threeG,
    fourG,
    wifi,
  ];

  /// Serialises this condition to a JSON-compatible map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'connectionSetupMs': connectionSetup.inMilliseconds,
    'latencyMs': latency.inMilliseconds,
    'jitterMs': latencyJitter.inMilliseconds,
    'distribution': distribution.name,
    'downloadKbps': downloadKbps,
    'uploadKbps': uploadKbps,
    'packetLoss': packetLoss,
  };

  /// Restores a condition from [json] produced by [toJson].
  factory NetworkCondition.fromJson(Map<String, dynamic> json) {
    return NetworkCondition(
      name: json['name'] as String? ?? 'custom',
      connectionSetup: Duration(
        milliseconds: (json['connectionSetupMs'] as num?)?.toInt() ?? 0,
      ),
      latency: Duration(
        milliseconds: (json['latencyMs'] as num?)?.toInt() ?? 0,
      ),
      latencyJitter: Duration(
        milliseconds: (json['jitterMs'] as num?)?.toInt() ?? 0,
      ),
      distribution:
          LatencyDistribution.values.asNameMap()[json['distribution']] ??
          LatencyDistribution.uniform,
      downloadKbps: (json['downloadKbps'] as num?)?.toInt() ?? 0,
      uploadKbps: (json['uploadKbps'] as num?)?.toInt() ?? 0,
      packetLoss: (json['packetLoss'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Returns a copy of this condition with the given fields replaced.
  ///
  /// Pass [bandwidthKbps] to set both [downloadKbps] and [uploadKbps] at once.
  NetworkCondition copyWith({
    String? name,
    Duration? connectionSetup,
    Duration? latency,
    Duration? latencyJitter,
    LatencyDistribution? distribution,
    int? downloadKbps,
    int? uploadKbps,
    int? bandwidthKbps,
    double? packetLoss,
  }) {
    return NetworkCondition(
      name: name ?? this.name,
      connectionSetup: connectionSetup ?? this.connectionSetup,
      latency: latency ?? this.latency,
      latencyJitter: latencyJitter ?? this.latencyJitter,
      distribution: distribution ?? this.distribution,
      downloadKbps: bandwidthKbps ?? downloadKbps ?? this.downloadKbps,
      uploadKbps: bandwidthKbps ?? uploadKbps ?? this.uploadKbps,
      packetLoss: packetLoss ?? this.packetLoss,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NetworkCondition &&
        other.name == name &&
        other.connectionSetup == connectionSetup &&
        other.latency == latency &&
        other.latencyJitter == latencyJitter &&
        other.distribution == distribution &&
        other.downloadKbps == downloadKbps &&
        other.uploadKbps == uploadKbps &&
        other.packetLoss == packetLoss;
  }

  @override
  int get hashCode => Object.hash(
    name,
    connectionSetup,
    latency,
    latencyJitter,
    distribution,
    downloadKbps,
    uploadKbps,
    packetLoss,
  );

  @override
  String toString() {
    return 'NetworkCondition($name, setup: ${connectionSetup.inMilliseconds}ms, '
        'latency: ${latency.inMilliseconds}ms, '
        'bandwidth: ${bandwidthKbps}kbps, packetLoss: $packetLoss)';
  }
}
