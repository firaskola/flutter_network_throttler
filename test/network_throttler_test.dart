import 'package:fake_async/fake_async.dart';
import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NetworkThrottler.transferDuration', () {
    test('returns zero for unlimited bandwidth', () {
      expect(NetworkThrottler.transferDuration(1024, 0), Duration.zero);
    });

    test('returns zero for empty payloads', () {
      expect(NetworkThrottler.transferDuration(0, 1000), Duration.zero);
    });

    test('computes transfer time from bytes and kbps', () {
      // 1000 bytes = 8000 bits, at 8 kbps => 1 second.
      expect(
        NetworkThrottler.transferDuration(1000, 8),
        const Duration(seconds: 1),
      );
    });
  });

  group('NetworkThrottler.throttle', () {
    test('returns the operation result when conditions are perfect', () async {
      final throttler = NetworkThrottler(seed: 1);
      expect(await throttler.throttle(() async => 42), 42);
    });

    test('skips throttling entirely when disabled', () async {
      final throttler = NetworkThrottler(
        condition: NetworkCondition.offline,
        enabled: false,
      );
      expect(await throttler.throttle(() async => 'ok'), 'ok');
    });

    test('throws SimulatedNetworkException when offline', () async {
      final throttler = NetworkThrottler(condition: NetworkCondition.offline);
      await expectLater(
        throttler.throttle(() async => 'never'),
        throwsA(isA<SimulatedNetworkException>()),
      );
    });

    test('applies the configured latency', () {
      fakeAsync((async) {
        final throttler = NetworkThrottler(
          condition: const NetworkCondition(
            latency: Duration(milliseconds: 500),
          ),
          seed: 1,
        );

        Object? result;
        throttler.throttle(() async => 'done').then((value) => result = value);

        async.elapse(const Duration(milliseconds: 499));
        expect(result, isNull);

        async.elapse(const Duration(milliseconds: 2));
        expect(result, 'done');
      });
    });
  });
}
