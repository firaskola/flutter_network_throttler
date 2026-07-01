import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JSON round-trips', () {
    test('NetworkCondition', () {
      const c = NetworkCondition.threeG;
      expect(NetworkCondition.fromJson(c.toJson()), c);
    });

    test('NetworkCondition with connection setup and distribution', () {
      const c = NetworkCondition(
        name: 'Custom',
        connectionSetup: Duration(milliseconds: 250),
        latency: Duration(milliseconds: 120),
        latencyJitter: Duration(milliseconds: 60),
        distribution: LatencyDistribution.gaussian,
        downloadKbps: 1500,
        uploadKbps: 700,
        packetLoss: 0.12,
      );
      expect(NetworkCondition.fromJson(c.toJson()), c);
    });

    test('FailureInjection', () {
      const f = FailureInjection(
        enabled: true,
        type: FailureType.http403,
        probability: 0.3,
      );
      expect(FailureInjection.fromJson(f.toJson()), f);
    });

    test('FailureInjection with 429 retry-after', () {
      const f = FailureInjection(
        enabled: true,
        type: FailureType.http429,
        probability: 0.5,
        retryAfter: Duration(seconds: 7),
      );
      expect(FailureInjection.fromJson(f.toJson()), f);
    });

    test('ResponseTampering', () {
      for (final mode in TamperMode.values) {
        final t = ResponseTampering(
          enabled: true,
          mode: mode,
          probability: 0.25,
        );
        expect(ResponseTampering.fromJson(t.toJson()), t);
      }
    });

    test('EndpointRule with host/query/headers/anchored', () {
      const rule = EndpointRule(
        method: 'GET',
        pattern: '/search',
        action: DelayAction(Duration(milliseconds: 300)),
        host: '*.example.com',
        query: {'q': '*'},
        headers: {'x-test': 'on'},
        anchored: true,
      );
      expect(EndpointRule.fromJson(rule.toJson()), rule);
    });

    test('RuleAction variants', () {
      for (final action in <RuleAction>[
        const DelayAction(Duration(milliseconds: 800)),
        const FailAction(FailureType.http500),
        const PassThroughAction(),
      ]) {
        expect(RuleAction.fromJson(action.toJson()), action);
      }
    });

    test('EndpointRule', () {
      const rule = EndpointRule(
        method: 'POST',
        pattern: '/v1/upload',
        action: FailAction(FailureType.http500),
      );
      expect(EndpointRule.fromJson(rule.toJson()), rule);
    });

    test('ThrottleProfile with rules', () {
      final profile = ThrottleProfile.initial.copyWith(
        enabled: false,
        presetName: 'Custom',
        rules: const [
          EndpointRule(pattern: '/v1/feed', action: PassThroughAction()),
          EndpointRule(
            method: 'GET',
            pattern: '*.cdn/*',
            action: DelayAction(Duration(milliseconds: 200)),
          ),
        ],
      );
      expect(ThrottleProfile.fromJson(profile.toJson()), profile);
    });

    test('ThrottleProfile with tampering and 429 failure', () {
      final profile = ThrottleProfile.initial.copyWith(
        failure: const FailureInjection(
          enabled: true,
          type: FailureType.http429,
          probability: 0.2,
          retryAfter: Duration(seconds: 3),
        ),
        tampering: const ResponseTampering(
          enabled: true,
          mode: TamperMode.corrupt,
          probability: 0.4,
        ),
      );
      expect(ThrottleProfile.fromJson(profile.toJson()), profile);
    });
  });
}
