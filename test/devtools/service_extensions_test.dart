import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('registerThrottleServiceExtensions', () {
    test('registers the expected extensions in debug mode', () {
      final controller = ThrottleController();
      // Tests run in debug mode, so registration is active.
      final count = registerThrottleServiceExtensions(controller);
      expect(count, 5);
    });

    test('throws if registered twice (proving the names took effect)', () {
      final controller = ThrottleController();
      // The previous test already registered these names on this isolate, so a
      // second attempt must fail — confirming real VM-service registration.
      expect(
        () => registerThrottleServiceExtensions(controller),
        throwsArgumentError,
      );
    });
  });
}
