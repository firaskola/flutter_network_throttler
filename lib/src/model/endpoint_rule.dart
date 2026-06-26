import 'package:meta/meta.dart';

import 'failure.dart';

/// The visual/behavioural category of a [RuleAction], used for log styling and
/// chip colours in the control panel.
enum RuleKind {
  /// Adds extra latency.
  slow,

  /// Forces a failure.
  fail,

  /// Bypasses throttling entirely.
  pass,
}

/// What a matching [EndpointRule] does to a request.
@immutable
sealed class RuleAction {
  const RuleAction();

  /// Short label rendered on the rule's action chip, e.g. `+800ms`.
  String get label;

  /// The category used for styling.
  RuleKind get kind;

  /// Serialises this action to a JSON-compatible map.
  Map<String, dynamic> toJson();

  /// Restores an action from [json] produced by [toJson].
  factory RuleAction.fromJson(Map<String, dynamic> json) {
    switch (json['kind']) {
      case 'delay':
        return DelayAction(
          Duration(milliseconds: (json['ms'] as num?)?.toInt() ?? 0),
        );
      case 'fail':
        return FailAction(
          FailureType.values.asNameMap()[json['type']] ?? FailureType.http500,
        );
      case 'pass':
      default:
        return const PassThroughAction();
    }
  }
}

/// Adds [extra] latency on top of the active condition.
@immutable
class DelayAction extends RuleAction {
  /// Creates a delay action.
  const DelayAction(this.extra);

  /// Additional latency applied to matching requests.
  final Duration extra;

  @override
  String get label => '+${extra.inMilliseconds}ms';

  @override
  RuleKind get kind => RuleKind.slow;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': 'delay',
    'ms': extra.inMilliseconds,
  };

  @override
  bool operator ==(Object other) =>
      other is DelayAction && other.extra == extra;

  @override
  int get hashCode => extra.hashCode;
}

/// Forces matching requests to fail with [type].
@immutable
class FailAction extends RuleAction {
  /// Creates a fail action.
  const FailAction(this.type);

  /// The failure injected into matching requests.
  final FailureType type;

  @override
  String get label => 'fail ${type.code}';

  @override
  RuleKind get kind => RuleKind.fail;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': 'fail',
    'type': type.name,
  };

  @override
  bool operator ==(Object other) => other is FailAction && other.type == type;

  @override
  int get hashCode => type.hashCode;
}

/// Lets matching requests bypass all throttling.
@immutable
class PassThroughAction extends RuleAction {
  /// Creates a pass-through action.
  const PassThroughAction();

  @override
  String get label => 'pass-through';

  @override
  RuleKind get kind => RuleKind.pass;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'kind': 'pass'};

  @override
  bool operator ==(Object other) => other is PassThroughAction;

  @override
  int get hashCode => (PassThroughAction).hashCode;
}

/// A rule that overrides throttling behaviour for requests whose method and URL
/// match [method] and [pattern].
@immutable
class EndpointRule {
  /// Creates an endpoint rule.
  ///
  /// A `null` [method] matches any HTTP method. [pattern] is a glob where `*`
  /// matches any run of characters; it is tested against both the full URL and
  /// the request path so patterns like `/v1/feed` or `*.cdn.img/*` both work.
  const EndpointRule({
    this.method,
    required this.pattern,
    required this.action,
  });

  /// The HTTP method to match (case-insensitive), or `null` for any.
  final String? method;

  /// The glob pattern matched against the request URL/path.
  final String pattern;

  /// What happens to matching requests.
  final RuleAction action;

  /// Whether this rule applies to the given [requestMethod] and [url].
  bool matches(String requestMethod, Uri url) {
    if (method != null &&
        method!.toUpperCase() != requestMethod.toUpperCase()) {
      return false;
    }
    final regex = _globToRegExp(pattern);
    return regex.hasMatch(url.toString()) || regex.hasMatch(url.path);
  }

  /// Serialises this rule to a JSON-compatible map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    if (method != null) 'method': method,
    'pattern': pattern,
    'action': action.toJson(),
  };

  /// Restores a rule from [json] produced by [toJson].
  factory EndpointRule.fromJson(Map<String, dynamic> json) {
    return EndpointRule(
      method: json['method'] as String?,
      pattern: json['pattern'] as String? ?? '',
      action: RuleAction.fromJson(
        (json['action'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{'kind': 'pass'},
      ),
    );
  }

  /// Returns a copy with the given fields replaced.
  EndpointRule copyWith({String? method, String? pattern, RuleAction? action}) {
    return EndpointRule(
      method: method ?? this.method,
      pattern: pattern ?? this.pattern,
      action: action ?? this.action,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EndpointRule &&
      other.method == method &&
      other.pattern == pattern &&
      other.action == action;

  @override
  int get hashCode => Object.hash(method, pattern, action);

  @override
  String toString() =>
      'EndpointRule(${method ?? 'ANY'} $pattern -> ${action.label})';
}

/// Compiles a glob (only `*` is special) into a case-insensitive [RegExp] that
/// matches anywhere in the candidate string.
RegExp _globToRegExp(String glob) {
  final buffer = StringBuffer();
  for (final char in glob.split('')) {
    if (char == '*') {
      buffer.write('.*');
    } else {
      buffer.write(RegExp.escape(char));
    }
  }
  return RegExp(buffer.toString(), caseSensitive: false);
}
