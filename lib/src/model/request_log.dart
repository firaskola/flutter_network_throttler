import 'package:meta/meta.dart';

/// The outcome of a request as seen by the throttler, driving the coloured dot
/// and meta text in the live log.
enum RequestOutcome {
  /// Completed normally (no throttling applied, or pass-through).
  ok,

  /// Completed but was slowed down (latency/bandwidth/extra delay).
  throttled,

  /// Did not complete successfully (dropped, timed out, or injected error).
  failed,
}

/// What kind of traffic a log entry represents, so the live log can tag
/// WebSocket frames distinctly from HTTP requests.
enum RequestKind {
  /// A one-shot HTTP request/response.
  http,

  /// A WebSocket handshake or frame.
  webSocket,
}

/// A single captured entry in the live request log.
@immutable
class RequestLogEntry {
  /// Creates a log entry.
  const RequestLogEntry({
    required this.method,
    required this.url,
    required this.outcome,
    required this.meta,
    this.appliedDelay,
    this.kind = RequestKind.http,
  });

  /// The HTTP method (e.g. `GET`) or WebSocket frame label (e.g. `WS↓`).
  final String method;

  /// Whether this entry is HTTP or WebSocket traffic.
  final RequestKind kind;

  /// The requested URL.
  final Uri url;

  /// How the request resolved.
  final RequestOutcome outcome;

  /// Short monospace detail shown on the right, e.g. `+842ms`, `500`, `118ms`.
  final String meta;

  /// The total artificial delay applied, when relevant.
  final Duration? appliedDelay;

  /// The path-and-query portion of [url], for compact display.
  String get path {
    final query = url.hasQuery ? '?${url.query}' : '';
    return '${url.path}$query';
  }

  @override
  String toString() =>
      'RequestLogEntry($method $path -> ${outcome.name} $meta)';
}
