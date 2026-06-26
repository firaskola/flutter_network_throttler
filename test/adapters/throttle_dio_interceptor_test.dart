import 'package:dio/dio.dart';
import 'package:flutter_network_throttler/dio.dart';
import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

/// A dio adapter that always returns 200 without touching the network, so we
/// exercise the interceptor in isolation.
class _OkAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      'hello',
      200,
      headers: {
        Headers.contentTypeHeader: ['text/plain'],
      },
    );
  }
}

Dio buildDio(ThrottleController controller) {
  final dio = Dio()
    ..httpClientAdapter = _OkAdapter()
    ..interceptors.add(ThrottleInterceptor(controller));
  return dio;
}

void main() {
  final url = 'https://api.test/v1/feed';

  group('ThrottleInterceptor', () {
    test('passes through and logs ok when disabled', () async {
      final controller = ThrottleController(
        profile: const ThrottleProfile(enabled: false),
      );
      final response = await buildDio(controller).get<dynamic>(url);
      expect(response.statusCode, 200);
      expect(controller.log, hasLength(1));
      expect(controller.log.first.outcome, RequestOutcome.ok);
    });

    test('rejects with badResponse when an HTTP error is injected', () async {
      final controller = ThrottleController(
        profile: const ThrottleProfile(
          condition: NetworkCondition.perfect,
          failure: FailureInjection(
            enabled: true,
            type: FailureType.http403,
            probability: 1.0,
          ),
        ),
      );

      await expectLater(
        buildDio(controller).get<dynamic>(url),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            403,
          ),
        ),
      );
      expect(controller.log.first.outcome, RequestOutcome.failed);
      expect(controller.log.first.meta, '403');
    });

    test('rejects with a connection error on packet loss', () async {
      final controller = ThrottleController(
        profile: const ThrottleProfile(
          condition: NetworkCondition(packetLoss: 1.0),
        ),
      );

      await expectLater(
        buildDio(controller).get<dynamic>(url),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.connectionError,
          ),
        ),
      );
      expect(controller.log.first.outcome, RequestOutcome.failed);
    });
  });
}
