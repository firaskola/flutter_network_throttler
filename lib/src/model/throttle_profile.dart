import 'package:meta/meta.dart';

import 'endpoint_rule.dart';
import 'failure.dart';
import 'network_condition.dart';
import 'response_tampering.dart';

/// The complete, serialisable throttling configuration: the master switch, the
/// active [condition], failure injection, and per-endpoint rules.
///
/// This is the single value a `ThrottleController` exposes and mutates, and the
/// thing the engine reads when deciding what to do with each request.
@immutable
class ThrottleProfile {
  /// Creates a profile.
  const ThrottleProfile({
    this.enabled = true,
    this.presetName = '3G',
    this.condition = NetworkCondition.threeG,
    this.failure = const FailureInjection(),
    this.tampering = const ResponseTampering(),
    this.rules = const <EndpointRule>[],
  });

  /// Whether throttling is currently applied. When `false`, traffic passes
  /// through untouched.
  final bool enabled;

  /// The name of the active preset, or `'Custom'` once a slider is moved.
  final String presetName;

  /// The active network condition.
  final NetworkCondition condition;

  /// Failure-injection settings.
  final FailureInjection failure;

  /// Response-tampering settings (truncate / corrupt / garbage bodies).
  final ResponseTampering tampering;

  /// Per-endpoint override rules, evaluated in order (first match wins).
  final List<EndpointRule> rules;

  /// The presets offered as chips in the control panel.
  static const List<NetworkCondition> defaultPresets = NetworkCondition.presets;

  /// A reasonable default profile (3G, failure injection off).
  static const ThrottleProfile initial = ThrottleProfile();

  /// Serialises this profile to a JSON-compatible map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'enabled': enabled,
    'presetName': presetName,
    'condition': condition.toJson(),
    'failure': failure.toJson(),
    'tampering': tampering.toJson(),
    'rules': rules.map((r) => r.toJson()).toList(),
  };

  /// Restores a profile from [json] produced by [toJson].
  factory ThrottleProfile.fromJson(Map<String, dynamic> json) {
    final rules = (json['rules'] as List?) ?? const <dynamic>[];
    return ThrottleProfile(
      enabled: json['enabled'] as bool? ?? true,
      presetName: json['presetName'] as String? ?? '3G',
      condition: NetworkCondition.fromJson(
        (json['condition'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      failure: FailureInjection.fromJson(
        (json['failure'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      tampering: ResponseTampering.fromJson(
        (json['tampering'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      rules: rules
          .map((e) => EndpointRule.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  /// Returns a copy with the given fields replaced.
  ThrottleProfile copyWith({
    bool? enabled,
    String? presetName,
    NetworkCondition? condition,
    FailureInjection? failure,
    ResponseTampering? tampering,
    List<EndpointRule>? rules,
  }) {
    return ThrottleProfile(
      enabled: enabled ?? this.enabled,
      presetName: presetName ?? this.presetName,
      condition: condition ?? this.condition,
      failure: failure ?? this.failure,
      tampering: tampering ?? this.tampering,
      rules: rules ?? this.rules,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ThrottleProfile &&
      other.enabled == enabled &&
      other.presetName == presetName &&
      other.condition == condition &&
      other.failure == failure &&
      other.tampering == tampering &&
      _listEquals(other.rules, rules);

  @override
  int get hashCode => Object.hash(
    enabled,
    presetName,
    condition,
    failure,
    tampering,
    Object.hashAll(rules),
  );
}

bool _listEquals(List<EndpointRule> a, List<EndpointRule> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
