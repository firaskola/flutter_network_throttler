import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';

void main() {
  final uri = Uri.parse('https://api.test/v1/feed');

  MockClient okClient([String body = 'hello']) =>
      MockClient((request) async => Response(body, 200));

  group('ThrottleClient', () {
    test('passes through and logs ok when disabled', () async {
      final controller = ThrottleController(
        profile: const ThrottleProfile(enabled: false),
      );
      final client = ThrottleClient(okClient(), controller: controller);

      final response = await client.get(uri);
      expect(response.statusCode, 200);
      expect(response.body, 'hello');
      expect(controller.log, hasLength(1));
      expect(controller.log.first.outcome, RequestOutcome.ok);
    });

    test('applies latency and logs throttled', () {
      fakeAsync((async) {
        final controller = ThrottleController(
          profile: const ThrottleProfile(
            condition: NetworkCondition(latency: Duration(milliseconds: 300)),
          ),
          seed: 1,
        );
        final client = ThrottleClient(okClient(), controller: controller);

        Response? response;
        client.get(uri).then((r) => response = r);

        async.elapse(const Duration(milliseconds: 299));
        expect(response, isNull);

        async.elapse(const Duration(milliseconds: 2));
        expect(response, isNotNull);
        expect(response!.statusCode, 200);
        expect(controller.log.first.outcome, RequestOutcome.throttled);
        expect(controller.log.first.meta, startsWith('+'));
      });
    });

    test('synthesizes an HTTP error from failure injection', () async {
      final controller = ThrottleController(
        profile: const ThrottleProfile(
          condition: NetworkCondition.perfect,
          failure: FailureInjection(
            enabled: true,
            type: FailureType.http500,
            probability: 1.0,
          ),
        ),
      );
      final client = ThrottleClient(okClient(), controller: controller);

      final response = await client.get(uri);
      expect(response.statusCode, 500);
      expect(controller.log.first.outcome, RequestOutcome.failed);
      expect(controller.log.first.meta, '500');
    });

    test('throws ClientException on packet loss', () async {
      final controller = ThrottleController(
        profile: const ThrottleProfile(
          condition: NetworkCondition(packetLoss: 1.0),
        ),
      );
      final client = ThrottleClient(okClient(), controller: controller);

      await expectLater(client.get(uri), throwsA(isA<ClientException>()));
      expect(controller.log.first.outcome, RequestOutcome.failed);
    });

    test('throws TimeoutException when timeout is injected', () async {
      final controller = ThrottleController(
        profile: const ThrottleProfile(
          condition: NetworkCondition.perfect,
          failure: FailureInjection(
            enabled: true,
            type: FailureType.timeout,
            probability: 1.0,
          ),
        ),
      );
      final client = ThrottleClient(okClient(), controller: controller);

      await expectLater(client.get(uri), throwsA(isA<TimeoutException>()));
      expect(controller.log.first.meta, 'timeout');
    });

    test(
      'a pass-through rule bypasses an otherwise-offline condition',
      () async {
        final controller = ThrottleController(
          profile: const ThrottleProfile(
            condition: NetworkCondition(packetLoss: 1.0),
            rules: [
              EndpointRule(pattern: '/v1/feed', action: PassThroughAction()),
            ],
          ),
        );
        final client = ThrottleClient(okClient(), controller: controller);

        final response = await client.get(uri);
        expect(response.statusCode, 200);
        expect(controller.log.first.outcome, RequestOutcome.ok);
      },
    );
  });
}
