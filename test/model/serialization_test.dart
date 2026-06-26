import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JSON round-trips', () {
    test('NetworkCondition', () {
      const c = NetworkCondition.threeG;
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
  });
}
