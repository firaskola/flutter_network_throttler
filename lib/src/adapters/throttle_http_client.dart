import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';

import '../engine/throttle_controller.dart';
import '../engine/throttle_engine.dart';
import '../model/failure.dart';
import '../model/request_log.dart';

/// A drop-in `package:http` [Client] that routes every request through a
/// [ThrottleController], applying the configured latency, bandwidth limits,
/// packet loss, failure injection, response tampering, and per-endpoint rules —
/// and recording each request in the live log.
///
/// Wrap whatever client you already use:
///
/// ```dart
/// final controller = ThrottleController();
/// final client = ThrottleClient(Client(), controller: controller);
///
/// final response = await client.get(Uri.parse('https://api.example.com/feed'));
/// ```
///
/// By default the response body is **streamed through progressively**: each
/// chunk is delayed by its own transfer time under the bandwidth cap, so the
/// body is never fully buffered in memory and download progress reaches your UI
/// as it arrives. Set [streamResponses] to `false` to buffer the whole body
/// before returning (the body is always buffered when response tampering is
/// applied to that request, since damaging it requires the full payload).
///
/// Closing the [ThrottleClient] also closes the wrapped [inner] client.
class ThrottleClient extends BaseClient {
  /// Creates a throttling client wrapping [inner].
  ThrottleClient(
    this.inner, {
    required this.controller,
    this.streamResponses = true,
  });

  /// The underlying client that performs the real network I/O.
  final Client inner;

  /// The controller whose profile drives throttling decisions.
  final ThrottleController controller;

  /// Whether response bodies are streamed through with bandwidth applied
  /// progressively (`true`, the default) or fully buffered before returning
  /// (`false`).
  final bool streamResponses;

  ThrottleEngine get _engine => controller.engine;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final plan = _engine.planRequest(
      request.method,
      request.url,
      requestHeaders: request.headers,
    );

    if (plan.passThrough) {
      final stopwatch = Stopwatch()..start();
      final response = await inner.send(request);
      stopwatch.stop();
      _engine.record(
        _entry(
          request,
          RequestOutcome.ok,
          '${stopwatch.elapsedMilliseconds}ms',
          null,
        ),
      );
      return response;
    }

    // Pre-request latency (connection setup + base + jitter + any rule delay).
    if (plan.latency > Duration.zero) {
      await Future<void>.delayed(plan.latency);
    }

    // Injected / packet-loss failure: fail without (or instead of) sending.
    final failure = plan.failure;
    if (failure != null) {
      return _applyFailure(request, failure, plan.latency);
    }

    // Upload bandwidth delay based on the request body size.
    final requestBytes = request.contentLength ?? 0;
    final uploadDelay = _engine.bandwidthDelay(requestBytes, upload: true);
    if (uploadDelay > Duration.zero) {
      await Future<void>.delayed(uploadDelay);
    }

    final preDelay = plan.latency + uploadDelay;
    final stopwatch = Stopwatch()..start();
    final response = await inner.send(request);

    // Tampering needs the whole body; so does the opt-in buffering mode.
    final tampering = plan.tampering;
    if (tampering != null || !streamResponses) {
      final bytes = await response.stream.toBytes();
      final downloadDelay = _engine.bandwidthDelay(bytes.length);
      if (downloadDelay > Duration.zero) {
        await Future<void>.delayed(downloadDelay);
      }
      stopwatch.stop();

      final body = tampering == null
          ? bytes
          : _engine.applyTampering(tampering, bytes);
      final artificial = preDelay + downloadDelay;
      final throttled = artificial > Duration.zero;
      final meta = tampering != null
          ? tampering.mode.code
          : (throttled
                ? '+${artificial.inMilliseconds}ms'
                : '${stopwatch.elapsedMilliseconds}ms');
      _engine.record(
        _entry(
          request,
          throttled ? RequestOutcome.throttled : RequestOutcome.ok,
          meta,
          throttled ? artificial : null,
        ),
      );

      return StreamedResponse(
        Stream<List<int>>.value(body),
        response.statusCode,
        // Keep the original content-length when truncating so the http client
        // sees the size mismatch a real truncated transfer would produce.
        contentLength: tampering == null ? body.length : response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    }

    // Streaming path: throttle each chunk as it flows, never buffering.
    return StreamedResponse(
      _throttledDownload(response.stream, request, preDelay, stopwatch),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  /// Delays each chunk by its transfer time under the download cap, logging the
  /// request once the body has finished draining (or is cancelled).
  Stream<List<int>> _throttledDownload(
    Stream<List<int>> source,
    BaseRequest request,
    Duration preDelay,
    Stopwatch stopwatch,
  ) async* {
    var downloadMicros = 0;
    var logged = false;
    void log() {
      if (logged) return;
      logged = true;
      stopwatch.stop();
      final artificial = preDelay + Duration(microseconds: downloadMicros);
      final throttled = artificial > Duration.zero;
      _engine.record(
        _entry(
          request,
          throttled ? RequestOutcome.throttled : RequestOutcome.ok,
          throttled
              ? '+${artificial.inMilliseconds}ms'
              : '${stopwatch.elapsedMilliseconds}ms',
          throttled ? artificial : null,
        ),
      );
    }

    try {
      await for (final chunk in source) {
        final delay = _engine.bandwidthDelay(chunk.length);
        if (delay > Duration.zero) {
          await Future<void>.delayed(delay);
          downloadMicros += delay.inMicroseconds;
        }
        yield chunk;
      }
    } finally {
      log();
    }
  }

  Future<StreamedResponse> _applyFailure(
    BaseRequest request,
    EngineFailure failure,
    Duration latency,
  ) async {
    final status = failure.httpStatus;
    if (status != null) {
      // Synthesize an error HTTP response so callers see a real status code.
      final body = utf8.encode(
        '{"error":"simulated","reason":"${failure.reason}","status":$status}',
      );
      final headers = <String, String>{'content-type': 'application/json'};
      final retryAfter = failure.retryAfter;
      if (retryAfter != null) {
        headers['retry-after'] = '${_retryAfterSeconds(retryAfter)}';
      }
      _engine.record(
        _entry(request, RequestOutcome.failed, '$status', latency),
      );
      return StreamedResponse(
        Stream<List<int>>.value(body),
        status,
        contentLength: body.length,
        request: request,
        headers: headers,
        reasonPhrase: failure.type.label,
      );
    }

    // Connection-level failure: no response is produced.
    final meta = failure.type == FailureType.timeout ? 'timeout' : 'no conn';
    _engine.record(_entry(request, RequestOutcome.failed, meta, latency));
    if (failure.type == FailureType.timeout) {
      throw TimeoutException(
        'Simulated request timeout (${failure.reason})',
        latency,
      );
    }
    throw ClientException(
      'Simulated connection failure (${failure.reason})',
      request.url,
    );
  }

  RequestLogEntry _entry(
    BaseRequest request,
    RequestOutcome outcome,
    String meta,
    Duration? appliedDelay,
  ) {
    return RequestLogEntry(
      method: request.method,
      url: request.url,
      outcome: outcome,
      meta: meta,
      appliedDelay: appliedDelay,
    );
  }

  @override
  void close() {
    inner.close();
    super.close();
  }
}

/// `Retry-After` is expressed in whole seconds; never advertise less than 1.
int _retryAfterSeconds(Duration d) => d.inSeconds < 1 ? 1 : d.inSeconds;
