import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThrottleProfile', () {
    test('initial profile is enabled 3G with failure injection off', () {
      const p = ThrottleProfile.initial;
      expect(p.enabled, isTrue);
      expect(p.presetName, '3G');
      expect(p.condition, NetworkCondition.threeG);
      expect(p.failure.enabled, isFalse);
      expect(p.rules, isEmpty);
    });

    test('copyWith replaces only given fields', () {
      const p = ThrottleProfile.initial;
      final q = p.copyWith(enabled: false, presetName: 'Custom');
      expect(q.enabled, isFalse);
      expect(q.presetName, 'Custom');
      expect(q.condition, NetworkCondition.threeG);
    });

    test('equality accounts for rules list', () {
      const a = ThrottleProfile.initial;
      final b = a.copyWith(
        rules: const [EndpointRule(pattern: '/x', action: PassThroughAction())],
      );
      expect(a == b, isFalse);
      final c = a.copyWith(
        rules: const [EndpointRule(pattern: '/x', action: PassThroughAction())],
      );
      expect(b, c);
    });
  });
}
