import 'package:meta/meta.dart';

/// Describes a set of simulated network characteristics — latency, jitter,
/// bandwidth, and packet loss — applied to throttled traffic.
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
  /// `0` means unlimited.
  const NetworkCondition({
    this.name = 'custom',
    this.latency = Duration.zero,
    this.latencyJitter = Duration.zero,
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
    Duration latency = Duration.zero,
    Duration jitter = Duration.zero,
    int bandwidthKbps = 0,
    double packetLoss = 0.0,
  }) : this(
         name: name,
         latency: latency,
         latencyJitter: jitter,
         downloadKbps: bandwidthKbps,
         uploadKbps: bandwidthKbps,
         packetLoss: packetLoss,
       );

  /// A human-readable label for this condition, e.g. `'3G'`.
  final String name;

  /// The base round-trip latency added before a request completes.
  final Duration latency;

  /// Random variation added to [latency], between `0` and this value.
  final Duration latencyJitter;

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

  /// A pristine connection: no latency, no bandwidth cap, never drops.
  static const NetworkCondition perfect = NetworkCondition(name: 'perfect');

  /// Fast, stable broadband / Wi-Fi.
  static const NetworkCondition wifi = NetworkCondition.simple(
    name: 'WiFi',
    latency: Duration(milliseconds: 8),
    jitter: Duration(milliseconds: 4),
    bandwidthKbps: 30000,
  );

  /// A good 4G / LTE mobile connection.
  static const NetworkCondition fourG = NetworkCondition.simple(
    name: '4G',
    latency: Duration(milliseconds: 35),
    jitter: Duration(milliseconds: 15),
    bandwidthKbps: 9000,
    packetLoss: 0.01,
  );

  /// A typical 3G mobile connection.
  static const NetworkCondition threeG = NetworkCondition.simple(
    name: '3G',
    latency: Duration(milliseconds: 100),
    jitter: Duration(milliseconds: 40),
    bandwidthKbps: 780,
    packetLoss: 0.03,
  );

  /// A slow, flaky 2G connection.
  static const NetworkCondition twoG = NetworkCondition.simple(
    name: '2G',
    latency: Duration(milliseconds: 650),
    jitter: Duration(milliseconds: 280),
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
    'latencyMs': latency.inMilliseconds,
    'jitterMs': latencyJitter.inMilliseconds,
    'downloadKbps': downloadKbps,
    'uploadKbps': uploadKbps,
    'packetLoss': packetLoss,
  };

  /// Restores a condition from [json] produced by [toJson].
  factory NetworkCondition.fromJson(Map<String, dynamic> json) {
    return NetworkCondition(
      name: json['name'] as String? ?? 'custom',
      latency: Duration(
        milliseconds: (json['latencyMs'] as num?)?.toInt() ?? 0,
      ),
      latencyJitter: Duration(
        milliseconds: (json['jitterMs'] as num?)?.toInt() ?? 0,
      ),
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
    Duration? latency,
    Duration? latencyJitter,
    int? downloadKbps,
    int? uploadKbps,
    int? bandwidthKbps,
    double? packetLoss,
  }) {
    return NetworkCondition(
      name: name ?? this.name,
      latency: latency ?? this.latency,
      latencyJitter: latencyJitter ?? this.latencyJitter,
      downloadKbps: bandwidthKbps ?? downloadKbps ?? this.downloadKbps,
      uploadKbps: bandwidthKbps ?? uploadKbps ?? this.uploadKbps,
      packetLoss: packetLoss ?? this.packetLoss,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NetworkCondition &&
        other.name == name &&
        other.latency == latency &&
        other.latencyJitter == latencyJitter &&
        other.downloadKbps == downloadKbps &&
        other.uploadKbps == uploadKbps &&
        other.packetLoss == packetLoss;
  }

  @override
  int get hashCode => Object.hash(
    name,
    latency,
    latencyJitter,
    downloadKbps,
    uploadKbps,
    packetLoss,
  );

  @override
  String toString() {
    return 'NetworkCondition($name, latency: ${latency.inMilliseconds}ms, '
        'bandwidth: ${bandwidthKbps}kbps, packetLoss: $packetLoss)';
  }
}
