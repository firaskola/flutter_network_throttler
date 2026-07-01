import 'dart:math';

import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NetworkCondition.sampleLatency', () {
    test('adds connection setup to base latency', () {
      const c = NetworkCondition(
        connectionSetup: Duration(milliseconds: 200),
        latency: Duration(milliseconds: 100),
      );
      // No jitter -> deterministic, no RNG draw.
      expect(c.sampleLatency(Random(1)), const Duration(milliseconds: 300));
    });

    test('zero jitter never draws from the RNG', () {
      const c = NetworkCondition(latency: Duration(milliseconds: 50));
      final shared = Random(7);
      final first = c.sampleLatency(shared);
      final next = shared.nextInt(1000); // would shift if sampleLatency drew
      expect(first, const Duration(milliseconds: 50));
      expect(next, Random(7).nextInt(1000));
    });

    for (final dist in LatencyDistribution.values) {
      test('$dist jitter stays within [base, base + jitter]', () {
        final c = NetworkCondition(
          latency: const Duration(milliseconds: 100),
          latencyJitter: const Duration(milliseconds: 80),
          distribution: dist,
        );
        final random = Random(99);
        for (var i = 0; i < 500; i++) {
          final value = c.sampleLatency(random);
          expect(
            value,
            greaterThanOrEqualTo(const Duration(milliseconds: 100)),
          );
          expect(value, lessThanOrEqualTo(const Duration(milliseconds: 180)));
        }
      });
    }

    test('is deterministic under the same seed', () {
      const c = NetworkCondition(
        latency: Duration(milliseconds: 100),
        latencyJitter: Duration(milliseconds: 50),
        distribution: LatencyDistribution.gaussian,
      );
      expect(c.sampleLatency(Random(5)), c.sampleLatency(Random(5)));
    });
  });
}
