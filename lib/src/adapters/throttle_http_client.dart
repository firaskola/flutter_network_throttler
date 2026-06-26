import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';

import '../engine/throttle_controller.dart';
import '../engine/throttle_engine.dart';
import '../model/failure.dart';
import '../model/request_log.dart';

/// A drop-in `package:http` [Client] that routes every request through a
/// [ThrottleController], applying the configured latency, bandwidth limits,
/// packet loss, failure injection, and per-endpoint rules — and recording each
/// request in the live log.
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
/// Closing the [ThrottleClient] also closes the wrapped [inner] client.
class ThrottleClient extends BaseClient {
  /// Creates a throttling client wrapping [inner].
  ThrottleClient(this.inner, {required this.controller});

  /// The underlying client that performs the real network I/O.
  final Client inner;

  /// The controller whose profile drives throttling decisions.
  final ThrottleController controller;

  ThrottleEngine get _engine => controller.engine;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final plan = _engine.planRequest(request.method, request.url);

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

    // Pre-request latency (base + jitter + any rule delay).
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

    final stopwatch = Stopwatch()..start();
    final response = await inner.send(request);
    final bytes = await response.stream.toBytes();
    stopwatch.stop();

    // Download bandwidth delay based on the response size.
    final downloadDelay = _engine.bandwidthDelay(bytes.length);
    if (downloadDelay > Duration.zero) {
      await Future<void>.delayed(downloadDelay);
    }

    final artificial = plan.latency + uploadDelay + downloadDelay;
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

    return StreamedResponse(
      Stream<List<int>>.value(bytes),
      response.statusCode,
      contentLength: bytes.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
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
      _engine.record(
        _entry(request, RequestOutcome.failed, '$status', latency),
      );
      return StreamedResponse(
        Stream<List<int>>.value(body),
        status,
        contentLength: body.length,
        request: request,
        headers: const {'content-type': 'application/json'},
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
