import 'dart:async';

import 'package:dio/dio.dart';

import '../engine/throttle_controller.dart';
import '../engine/throttle_engine.dart';
import '../model/failure.dart';
import '../model/request_log.dart';

/// A `package:dio` [Interceptor] that applies a [ThrottleController]'s profile
/// to every request — latency, bandwidth, packet loss, failure injection, and
/// per-endpoint rules — and records each request in the live log.
///
/// Attach it to your `Dio` instance:
///
/// ```dart
/// import 'package:flutter_network_throttler/dio.dart';
///
/// final controller = ThrottleController();
/// final dio = Dio()..interceptors.add(ThrottleInterceptor(controller));
/// ```
class ThrottleInterceptor extends Interceptor {
  /// Creates an interceptor driven by [controller].
  ThrottleInterceptor(this.controller);

  /// The controller whose profile drives throttling decisions.
  final ThrottleController controller;

  static const String _planKey = '_throttle_plan';
  static const String _startKey = '_throttle_start_us';

  ThrottleEngine get _engine => controller.engine;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final plan = _engine.planRequest(options.method, options.uri);

    if (plan.passThrough) {
      options.extra[_startKey] = _nowMicros();
      handler.next(options);
      return;
    }

    if (plan.latency > Duration.zero) {
      await Future<void>.delayed(plan.latency);
    }

    final failure = plan.failure;
    if (failure != null) {
      handler.reject(_failureException(options, failure, plan.latency), true);
      return;
    }

    // Upload bandwidth delay based on the request body size.
    final requestBytes = _bytesOf(options.headers, options.data);
    final uploadDelay = _engine.bandwidthDelay(requestBytes, upload: true);
    if (uploadDelay > Duration.zero) {
      await Future<void>.delayed(uploadDelay);
    }

    options.extra[_planKey] = plan.latency + uploadDelay;
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final options = response.requestOptions;

    // Pass-through: log real elapsed time, no extra delay.
    if (options.extra.containsKey(_startKey)) {
      final startUs = options.extra[_startKey] as int;
      final elapsedMs = (_nowMicros() - startUs) ~/ 1000;
      _engine.record(
        _entry(options, RequestOutcome.ok, '${elapsedMs}ms', null),
      );
      handler.next(response);
      return;
    }

    final priorDelay = (options.extra[_planKey] as Duration?) ?? Duration.zero;

    // Download bandwidth delay based on the response size.
    final responseBytes = _bytesOf(response.headers.map, response.data);
    final downloadDelay = _engine.bandwidthDelay(responseBytes);
    if (downloadDelay > Duration.zero) {
      await Future<void>.delayed(downloadDelay);
    }

    final artificial = priorDelay + downloadDelay;
    final throttled = artificial > Duration.zero;
    _engine.record(
      _entry(
        options,
        throttled ? RequestOutcome.throttled : RequestOutcome.ok,
        throttled ? '+${artificial.inMilliseconds}ms' : '0ms',
        throttled ? artificial : null,
      ),
    );
    handler.next(response);
  }

  DioException _failureException(
    RequestOptions options,
    EngineFailure failure,
    Duration latency,
  ) {
    final status = failure.httpStatus;
    if (status != null) {
      _engine.record(
        _entry(options, RequestOutcome.failed, '$status', latency),
      );
      return DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: status,
          statusMessage: failure.type.label,
          data: <String, dynamic>{
            'error': 'simulated',
            'reason': failure.reason,
            'status': status,
          },
        ),
      );
    }

    final isTimeout = failure.type == FailureType.timeout;
    _engine.record(
      _entry(
        options,
        RequestOutcome.failed,
        isTimeout ? 'timeout' : 'no conn',
        latency,
      ),
    );
    return DioException(
      requestOptions: options,
      type: isTimeout
          ? DioExceptionType.connectionTimeout
          : DioExceptionType.connectionError,
      error:
          'Simulated ${isTimeout ? 'timeout' : 'connection failure'} '
          '(${failure.reason})',
    );
  }

  RequestLogEntry _entry(
    RequestOptions options,
    RequestOutcome outcome,
    String meta,
    Duration? appliedDelay,
  ) {
    return RequestLogEntry(
      method: options.method,
      url: options.uri,
      outcome: outcome,
      meta: meta,
      appliedDelay: appliedDelay,
    );
  }

  /// Best-effort payload size: prefers a `content-length` header, then falls
  /// back to the length of string/byte bodies, otherwise `0`.
  int _bytesOf(Map<String, dynamic> headers, dynamic data) {
    final header = headers['content-length'] ?? headers['Content-Length'];
    if (header is List && header.isNotEmpty) {
      final parsed = int.tryParse('${header.first}');
      if (parsed != null) return parsed;
    } else if (header != null) {
      final parsed = int.tryParse('$header');
      if (parsed != null) return parsed;
    }
    if (data is String) return data.length;
    if (data is List<int>) return data.length;
    return 0;
  }

  int _nowMicros() => DateTime.now().microsecondsSinceEpoch;
}
