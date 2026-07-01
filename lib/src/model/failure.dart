import 'package:meta/meta.dart';

/// The kinds of failure the throttler can inject into otherwise-healthy
/// requests, mirroring the control panel's "Error type" grid.
enum FailureType {
  /// The request hangs and eventually times out.
  timeout,

  /// The server responds with HTTP 500 (Internal Server Error).
  http500,

  /// The server responds with HTTP 403 (Forbidden).
  http403,

  /// The server responds with HTTP 429 (Too Many Requests), carrying a
  /// `Retry-After` header so you can test rate-limit / back-off handling.
  http429,

  /// The connection cannot be established at all.
  noConnection;

  /// Short monospace code shown on the failure chip, e.g. `500`, `TIMEOUT`.
  String get code {
    switch (this) {
      case FailureType.timeout:
        return 'TIMEOUT';
      case FailureType.http500:
        return '500';
      case FailureType.http403:
        return '403';
      case FailureType.http429:
        return '429';
      case FailureType.noConnection:
        return 'NO CONN';
    }
  }

  /// Human-readable description of the failure.
  String get label {
    switch (this) {
      case FailureType.timeout:
        return 'Request timeout';
      case FailureType.http500:
        return 'Server error';
      case FailureType.http403:
        return 'Forbidden';
      case FailureType.http429:
        return 'Rate limited';
      case FailureType.noConnection:
        return 'No connection';
    }
  }

  /// Whether this failure carries a `Retry-After` header (HTTP 429).
  bool get hasRetryAfter => this == FailureType.http429;

  /// The HTTP status code this failure resolves to, or `null` when the failure
  /// is connection-level (no response is produced).
  int? get httpStatus {
    switch (this) {
      case FailureType.http500:
        return 500;
      case FailureType.http403:
        return 403;
      case FailureType.http429:
        return 429;
      case FailureType.timeout:
      case FailureType.noConnection:
        return null;
    }
  }
}

/// Configuration for randomly failing a fraction of requests with a chosen
/// [FailureType].
@immutable
class FailureInjection {
  /// Creates a failure-injection config.
  ///
  /// [probability] is in the inclusive range `0.0`–`1.0`.
  const FailureInjection({
    this.enabled = false,
    this.type = FailureType.http500,
    this.probability = 0.0,
    this.retryAfter = const Duration(seconds: 2),
  }) : assert(
         probability >= 0.0 && probability <= 1.0,
         'probability must be between 0.0 and 1.0',
       );

  /// Whether failure injection is active.
  final bool enabled;

  /// The kind of failure to inject when a request is selected to fail.
  final FailureType type;

  /// The probability `0.0`–`1.0` that an eligible request fails.
  final double probability;

  /// The `Retry-After` delay advertised on a 429 response. Only meaningful when
  /// [type] is [FailureType.http429]; ignored otherwise.
  final Duration retryAfter;

  /// Serialises this config to a JSON-compatible map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'enabled': enabled,
    'type': type.name,
    'probability': probability,
    'retryAfterMs': retryAfter.inMilliseconds,
  };

  /// Restores a config from [json] produced by [toJson].
  factory FailureInjection.fromJson(Map<String, dynamic> json) {
    return FailureInjection(
      enabled: json['enabled'] as bool? ?? false,
      type: FailureType.values.asNameMap()[json['type']] ?? FailureType.http500,
      probability: (json['probability'] as num?)?.toDouble() ?? 0.0,
      retryAfter: Duration(
        milliseconds: (json['retryAfterMs'] as num?)?.toInt() ?? 2000,
      ),
    );
  }

  /// Returns a copy with the given fields replaced.
  FailureInjection copyWith({
    bool? enabled,
    FailureType? type,
    double? probability,
    Duration? retryAfter,
  }) {
    return FailureInjection(
      enabled: enabled ?? this.enabled,
      type: type ?? this.type,
      probability: probability ?? this.probability,
      retryAfter: retryAfter ?? this.retryAfter,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FailureInjection &&
      other.enabled == enabled &&
      other.type == type &&
      other.probability == probability &&
      other.retryAfter == retryAfter;

  @override
  int get hashCode => Object.hash(enabled, type, probability, retryAfter);

  @override
  String toString() =>
      'FailureInjection(enabled: $enabled, type: ${type.code}, '
      'probability: $probability)';
}
