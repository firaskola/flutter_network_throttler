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

/// A rule that overrides throttling behaviour for requests matching its
/// [method], [pattern], and any optional [host] / [query] / [headers]
/// constraints.
@immutable
class EndpointRule {
  /// Creates an endpoint rule.
  ///
  /// A `null` [method] matches any HTTP method. [pattern] is a glob where `*`
  /// matches any run of characters; it is tested against both the full URL and
  /// the request path so patterns like `/v1/feed` or `*.cdn.img/*` both work.
  ///
  /// By default [pattern] (and [host]) match as a *substring* — `/v1/feed` also
  /// matches `/api/v1/feed/extra`. Set [anchored] to `true` to require the
  /// pattern to match the whole URL or path end-to-end.
  ///
  /// Narrow further with:
  /// * [host] — a glob matched (anchored) against the request host.
  /// * [query] — query parameters that must be present and glob-match.
  /// * [headers] — request headers (case-insensitive) that must be present and
  ///   glob-match.
  const EndpointRule({
    this.method,
    required this.pattern,
    required this.action,
    this.host,
    this.query = const <String, String>{},
    this.headers = const <String, String>{},
    this.anchored = false,
  });

  /// The HTTP method to match (case-insensitive), or `null` for any.
  final String? method;

  /// The glob pattern matched against the request URL/path.
  final String pattern;

  /// What happens to matching requests.
  final RuleAction action;

  /// An optional glob matched (anchored) against the request host, e.g.
  /// `*.cdn.example.com`. `null` matches any host.
  final String? host;

  /// Query parameters that must all be present and glob-match for the rule to
  /// apply. Empty means "don't constrain by query".
  final Map<String, String> query;

  /// Request headers (keys compared case-insensitively) that must all be
  /// present and glob-match. Empty means "don't constrain by header".
  final Map<String, String> headers;

  /// When `true`, [pattern] must match the entire URL/path rather than a
  /// substring.
  final bool anchored;

  /// Whether this rule applies to a request with [requestMethod], [url], and
  /// (optionally) [requestHeaders].
  bool matches(
    String requestMethod,
    Uri url, {
    Map<String, String> requestHeaders = const <String, String>{},
  }) {
    if (method != null &&
        method!.toUpperCase() != requestMethod.toUpperCase()) {
      return false;
    }

    final regex = _globToRegExp(pattern, anchored: anchored);
    if (!regex.hasMatch(url.toString()) && !regex.hasMatch(url.path)) {
      return false;
    }

    if (host != null &&
        !_globToRegExp(host!, anchored: true).hasMatch(url.host)) {
      return false;
    }

    for (final entry in query.entries) {
      final value = url.queryParameters[entry.key];
      if (value == null ||
          !_globToRegExp(entry.value, anchored: true).hasMatch(value)) {
        return false;
      }
    }

    if (headers.isNotEmpty) {
      final lower = <String, String>{
        for (final e in requestHeaders.entries) e.key.toLowerCase(): e.value,
      };
      for (final entry in headers.entries) {
        final value = lower[entry.key.toLowerCase()];
        if (value == null ||
            !_globToRegExp(entry.value, anchored: true).hasMatch(value)) {
          return false;
        }
      }
    }

    return true;
  }

  /// Serialises this rule to a JSON-compatible map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    if (method != null) 'method': method,
    'pattern': pattern,
    'action': action.toJson(),
    if (host != null) 'host': host,
    if (query.isNotEmpty) 'query': query,
    if (headers.isNotEmpty) 'headers': headers,
    if (anchored) 'anchored': true,
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
      host: json['host'] as String?,
      query:
          (json['query'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ??
          const <String, String>{},
      headers:
          (json['headers'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ??
          const <String, String>{},
      anchored: json['anchored'] as bool? ?? false,
    );
  }

  /// Returns a copy with the given fields replaced.
  EndpointRule copyWith({
    String? method,
    String? pattern,
    RuleAction? action,
    String? host,
    Map<String, String>? query,
    Map<String, String>? headers,
    bool? anchored,
  }) {
    return EndpointRule(
      method: method ?? this.method,
      pattern: pattern ?? this.pattern,
      action: action ?? this.action,
      host: host ?? this.host,
      query: query ?? this.query,
      headers: headers ?? this.headers,
      anchored: anchored ?? this.anchored,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EndpointRule &&
      other.method == method &&
      other.pattern == pattern &&
      other.action == action &&
      other.host == host &&
      other.anchored == anchored &&
      _mapEquals(other.query, query) &&
      _mapEquals(other.headers, headers);

  @override
  int get hashCode => Object.hash(
    method,
    pattern,
    action,
    host,
    anchored,
    _mapHash(query),
    _mapHash(headers),
  );

  @override
  String toString() =>
      'EndpointRule(${method ?? 'ANY'} $pattern -> ${action.label})';
}

/// Compiles a glob (only `*` is special) into a case-insensitive [RegExp].
///
/// When [anchored] is `true` the pattern must match the entire candidate
/// string; otherwise it matches anywhere within it.
RegExp _globToRegExp(String glob, {bool anchored = false}) {
  final buffer = StringBuffer();
  if (anchored) buffer.write('^');
  for (final char in glob.split('')) {
    if (char == '*') {
      buffer.write('.*');
    } else {
      buffer.write(RegExp.escape(char));
    }
  }
  if (anchored) buffer.write(r'$');
  return RegExp(buffer.toString(), caseSensitive: false);
}

bool _mapEquals(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

int _mapHash(Map<String, String> map) {
  var hash = 0;
  for (final entry in map.entries) {
    hash ^= Object.hash(entry.key, entry.value);
  }
  return hash;
}
