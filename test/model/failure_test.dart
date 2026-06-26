import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FailureType', () {
    test('exposes code, label, and http status', () {
      expect(FailureType.http500.code, '500');
      expect(FailureType.http500.httpStatus, 500);
      expect(FailureType.http403.httpStatus, 403);
      expect(FailureType.timeout.code, 'TIMEOUT');
      expect(FailureType.timeout.httpStatus, isNull);
      expect(FailureType.noConnection.code, 'NO CONN');
      expect(FailureType.noConnection.httpStatus, isNull);
    });
  });

  group('FailureInjection', () {
    test('defaults to disabled', () {
      const f = FailureInjection();
      expect(f.enabled, isFalse);
      expect(f.probability, 0.0);
    });

    test('copyWith replaces only given fields', () {
      const f = FailureInjection(enabled: true, probability: 0.2);
      final g = f.copyWith(type: FailureType.http403);
      expect(g.enabled, isTrue);
      expect(g.probability, 0.2);
      expect(g.type, FailureType.http403);
    });

    test('rejects out-of-range probability', () {
      expect(() => FailureInjection(probability: 2), throwsAssertionError);
    });

    test('equality is value based', () {
      expect(
        const FailureInjection(enabled: true),
        const FailureInjection(enabled: true),
      );
    });
  });
}
