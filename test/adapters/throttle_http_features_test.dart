import 'dart:convert';

import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';

void main() {
  final uri = Uri.parse('https://api.test/v1/feed');

  MockClient bodyClient(String body) =>
      MockClient((request) async => Response(body, 200));

  group('streaming downloads', () {
    test('deliver the body intact under a bandwidth cap', () async {
      final big = 'x' * 50000;
      final controller = ThrottleController(
        profile: const ThrottleProfile(
          condition: NetworkCondition(downloadKbps: 30000),
        ),
        seed: 1,
      );
      final client = ThrottleClient(bodyClient(big), controller: controller);

      final response = await client.get(uri);
      expect(response.statusCode, 200);
      expect(response.body.length, big.length, reason: 'no buffering loss');
      expect(controller.log.first.outcome, RequestOutcome.throttled);
    });
  });

  group('429 / Retry-After', () {
    test('synthesizes a 429 with a Retry-After header', () async {
      final controller = ThrottleController(
        profile: const ThrottleProfile(
          condition: NetworkCondition.perfect,
          failure: FailureInjection(
            enabled: true,
            type: FailureType.http429,
            probability: 1.0,
            retryAfter: Duration(seconds: 5),
          ),
        ),
      );
      final client = ThrottleClient(bodyClient('ok'), controller: controller);

      final response = await client.get(uri);
      expect(response.statusCode, 429);
      expect(response.headers['retry-after'], '5');
      expect(controller.log.first.meta, '429');
    });
  });

  group('response tampering', () {
    test('corrupt keeps the length but changes the bytes', () async {
      const original = 'the quick brown fox jumps over the lazy dog';
      final controller = ThrottleController(
        profile: const ThrottleProfile(
          condition: NetworkCondition.perfect,
          tampering: ResponseTampering(
            enabled: true,
            mode: TamperMode.corrupt,
            probability: 1.0,
          ),
        ),
        seed: 3,
      );
      final client = ThrottleClient(
        bodyClient(original),
        controller: controller,
      );

      final response = await client.get(uri);
      expect(response.bodyBytes.length, utf8.encode(original).length);
      expect(response.body, isNot(original));
      expect(controller.log.first.meta, 'corrupt');
    });

    test('truncate delivers a shorter body', () async {
      const original = 'abcdefghijklmnopqrstuvwxyz0123456789';
      final controller = ThrottleController(
        profile: const ThrottleProfile(
          condition: NetworkCondition.perfect,
          tampering: ResponseTampering(
            enabled: true,
            mode: TamperMode.truncate,
            probability: 1.0,
          ),
        ),
        seed: 2,
      );
      final client = ThrottleClient(
        bodyClient(original),
        controller: controller,
      );

      final response = await client.get(uri);
      expect(response.bodyBytes.length, lessThan(original.length));
      expect(controller.log.first.meta, 'trunc');
    });
  });

  group('header-based rules through the adapter', () {
    test('a header rule matches only when the header is present', () async {
      final controller = ThrottleController(
        profile: const ThrottleProfile(
          condition: NetworkCondition.perfect,
          rules: [
            EndpointRule(
              pattern: '/v1/feed',
              headers: {'x-test': 'on'},
              action: FailAction(FailureType.http403),
            ),
          ],
        ),
      );
      final client = ThrottleClient(bodyClient('ok'), controller: controller);

      final blocked = await client.get(uri, headers: {'X-Test': 'on'});
      expect(blocked.statusCode, 403);

      final allowed = await client.get(uri);
      expect(allowed.statusCode, 200);
    });
  });

  group('concurrency', () {
    test('many simultaneous throttled requests all complete and log', () async {
      final controller = ThrottleController(
        profile: const ThrottleProfile(
          condition: NetworkCondition(latency: Duration(milliseconds: 5)),
        ),
        logCapacity: 100,
        seed: 7,
      );
      final client = ThrottleClient(bodyClient('ok'), controller: controller);

      final responses = await Future.wait([
        for (var i = 0; i < 40; i++)
          client.get(uri.replace(queryParameters: {'i': '$i'})),
      ]);

      expect(responses, hasLength(40));
      expect(responses.every((r) => r.statusCode == 200), isTrue);
      expect(controller.log, hasLength(40));
    });
  });
}
