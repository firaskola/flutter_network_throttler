import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NetworkCondition', () {
    test('perfect preset has no latency and never drops', () {
      expect(NetworkCondition.perfect.latency, Duration.zero);
      expect(NetworkCondition.perfect.packetLoss, 0.0);
      expect(NetworkCondition.perfect.isOffline, isFalse);
    });

    test('offline preset always drops', () {
      expect(NetworkCondition.offline.packetLoss, 1.0);
      expect(NetworkCondition.offline.isOffline, isTrue);
    });

    test('design preset values match the spec', () {
      expect(
        NetworkCondition.threeG.latency,
        const Duration(milliseconds: 100),
      );
      expect(
        NetworkCondition.threeG.latencyJitter,
        const Duration(milliseconds: 40),
      );
      expect(NetworkCondition.threeG.bandwidthKbps, 780);
      expect(NetworkCondition.twoG.bandwidthKbps, 60);
      expect(NetworkCondition.wifi.bandwidthKbps, 30000);
      expect(NetworkCondition.fourG.bandwidthKbps, 9000);
    });

    test('simple constructor mirrors bandwidth into download and upload', () {
      const c = NetworkCondition.simple(bandwidthKbps: 500);
      expect(c.downloadKbps, 500);
      expect(c.uploadKbps, 500);
      expect(c.bandwidthKbps, 500);
    });

    test('presets chip list is offline -> wifi', () {
      expect(NetworkCondition.presets.map((c) => c.name).toList(), <String>[
        'Offline',
        '2G',
        '3G',
        '4G',
        'WiFi',
      ]);
    });

    test('copyWith bandwidthKbps sets both directions', () {
      final c = NetworkCondition.wifi.copyWith(bandwidthKbps: 1234);
      expect(c.downloadKbps, 1234);
      expect(c.uploadKbps, 1234);
    });

    test('rejects out-of-range packet loss', () {
      expect(() => NetworkCondition(packetLoss: 1.5), throwsAssertionError);
      expect(() => NetworkCondition(packetLoss: -0.1), throwsAssertionError);
    });

    test('equality is value based', () {
      expect(
        const NetworkCondition(latency: Duration(milliseconds: 100)),
        const NetworkCondition(latency: Duration(milliseconds: 100)),
      );
    });
  });
}
