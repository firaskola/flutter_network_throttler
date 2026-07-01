import 'dart:math';

import 'package:meta/meta.dart';

/// How a tampered response body is mangled.
enum TamperMode {
  /// Cut the body off early, as if the connection dropped mid-transfer.
  truncate,

  /// Flip a scattering of bytes, leaving the length intact but the content
  /// invalid — exercises checksum / parser-robustness paths.
  corrupt,

  /// Replace the whole body with random bytes.
  garbage;

  /// A short label for UI controls and the live log.
  String get label {
    switch (this) {
      case TamperMode.truncate:
        return 'Truncate';
      case TamperMode.corrupt:
        return 'Corrupt bytes';
      case TamperMode.garbage:
        return 'Garbage body';
    }
  }

  /// The compact code shown in the live log meta column.
  String get code {
    switch (this) {
      case TamperMode.truncate:
        return 'trunc';
      case TamperMode.corrupt:
        return 'corrupt';
      case TamperMode.garbage:
        return 'garbage';
    }
  }
}

/// Configuration for randomly damaging a fraction of *successful* response
/// bodies — truncating, corrupting, or replacing them — so you can test how
/// resilient your parsers and deserialisers are to malformed data.
///
/// Tampering only applies to responses that would otherwise succeed: it is
/// skipped for pass-through requests and for requests the engine has already
/// decided to fail.
@immutable
class ResponseTampering {
  /// Creates a response-tampering config.
  ///
  /// [probability] is in the inclusive range `0.0`–`1.0`.
  const ResponseTampering({
    this.enabled = false,
    this.mode = TamperMode.truncate,
    this.probability = 0.0,
  }) : assert(
         probability >= 0.0 && probability <= 1.0,
         'probability must be between 0.0 and 1.0',
       );

  /// Whether response tampering is active.
  final bool enabled;

  /// How a selected response body is mangled.
  final TamperMode mode;

  /// The probability `0.0`–`1.0` that an eligible response is tampered with.
  final double probability;

  /// Applies [mode] to [body], returning the mangled bytes. [random] makes the
  /// damage deterministic when seeded. An empty body is returned unchanged.
  List<int> apply(List<int> body, Random random) {
    if (body.isEmpty) return body;
    switch (mode) {
      case TamperMode.truncate:
        // Keep a random 10%–70% prefix (at least one byte short of the whole).
        final keep = (body.length * (0.1 + random.nextDouble() * 0.6))
            .floor()
            .clamp(0, body.length - 1);
        return body.sublist(0, keep);
      case TamperMode.corrupt:
        final out = List<int>.of(body);
        // Flip ~5% of bytes, at least one.
        final hits = max(1, (out.length * 0.05).round());
        for (var i = 0; i < hits; i++) {
          final at = random.nextInt(out.length);
          out[at] = out[at] ^ (1 + random.nextInt(255));
        }
        return out;
      case TamperMode.garbage:
        return List<int>.generate(body.length, (_) => random.nextInt(256));
    }
  }

  /// Serialises this config to a JSON-compatible map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'enabled': enabled,
    'mode': mode.name,
    'probability': probability,
  };

  /// Restores a config from [json] produced by [toJson].
  factory ResponseTampering.fromJson(Map<String, dynamic> json) {
    return ResponseTampering(
      enabled: json['enabled'] as bool? ?? false,
      mode: TamperMode.values.asNameMap()[json['mode']] ?? TamperMode.truncate,
      probability: (json['probability'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Returns a copy with the given fields replaced.
  ResponseTampering copyWith({
    bool? enabled,
    TamperMode? mode,
    double? probability,
  }) {
    return ResponseTampering(
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      probability: probability ?? this.probability,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ResponseTampering &&
      other.enabled == enabled &&
      other.mode == mode &&
      other.probability == probability;

  @override
  int get hashCode => Object.hash(enabled, mode, probability);

  @override
  String toString() =>
      'ResponseTampering(enabled: $enabled, mode: ${mode.code}, '
      'probability: $probability)';
}
