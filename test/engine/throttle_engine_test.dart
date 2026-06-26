import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

ThrottleEngine engineFor(ThrottleProfile profile, {int? seed}) {
  return ThrottleEngine(profile: () => profile, onLog: (_) {}, seed: seed);
}

void main() {
  final url = Uri.parse('https://api.test/v1/feed');

  group('ThrottleEngine.planRequest', () {
    test('disabled profile passes through', () {
      final engine = engineFor(const ThrottleProfile(enabled: false));
      final plan = engine.planRequest('GET', url);
      expect(plan.passThrough, isTrue);
      expect(plan.failure, isNull);
    });

    test('applies base latency from the condition', () {
      final engine = engineFor(
        const ThrottleProfile(
          condition: NetworkCondition(latency: Duration(milliseconds: 120)),
        ),
        seed: 1,
      );
      final plan = engine.planRequest('GET', url);
      expect(plan.passThrough, isFalse);
      expect(
        plan.latency,
        greaterThanOrEqualTo(const Duration(milliseconds: 120)),
      );
    });

    test('packet loss of 1.0 always drops with a connection-level failure', () {
      final engine = engineFor(
        const ThrottleProfile(condition: NetworkCondition(packetLoss: 1.0)),
      );
      final plan = engine.planRequest('GET', url);
      expect(plan.failure, isNotNull);
      expect(plan.failure!.isConnectionLevel, isTrue);
      expect(plan.failure!.reason, 'packet loss');
    });

    test('failure injection at p=1 injects the chosen type', () {
      final engine = engineFor(
        const ThrottleProfile(
          condition: NetworkCondition.perfect,
          failure: FailureInjection(
            enabled: true,
            type: FailureType.http500,
            probability: 1.0,
          ),
        ),
      );
      final plan = engine.planRequest('GET', url);
      expect(plan.failure, isNotNull);
      expect(plan.failure!.httpStatus, 500);
      expect(plan.failure!.reason, 'injection');
    });

    test('pass-through rule wins over conditions', () {
      final engine = engineFor(
        const ThrottleProfile(
          condition: NetworkCondition(packetLoss: 1.0),
          rules: [
            EndpointRule(pattern: '/v1/feed', action: PassThroughAction()),
          ],
        ),
      );
      final plan = engine.planRequest('GET', url);
      expect(plan.passThrough, isTrue);
      expect(plan.failure, isNull);
    });

    test('delay rule adds to latency', () {
      final engine = engineFor(
        const ThrottleProfile(
          condition: NetworkCondition(latency: Duration(milliseconds: 50)),
          rules: [
            EndpointRule(
              pattern: '/v1/feed',
              action: DelayAction(Duration(milliseconds: 800)),
            ),
          ],
        ),
        seed: 1,
      );
      final plan = engine.planRequest('GET', url);
      expect(plan.latency, const Duration(milliseconds: 850));
    });

    test('fail rule forces the rule failure', () {
      final engine = engineFor(
        const ThrottleProfile(
          condition: NetworkCondition.perfect,
          rules: [
            EndpointRule(
              method: 'POST',
              pattern: '/v1/upload',
              action: FailAction(FailureType.http500),
            ),
          ],
        ),
      );
      final plan = engine.planRequest(
        'POST',
        Uri.parse('https://api.test/v1/upload'),
      );
      expect(plan.failure!.httpStatus, 500);
      expect(plan.failure!.reason, 'rule');
    });
  });

  group('ThrottleEngine.bandwidthDelay', () {
    test('uses the download cap by default', () {
      // 1000 bytes = 8000 bits at 8 kbps => 1 second.
      final engine = engineFor(
        const ThrottleProfile(
          condition: NetworkCondition(downloadKbps: 8, uploadKbps: 16),
        ),
      );
      expect(engine.bandwidthDelay(1000), const Duration(seconds: 1));
      expect(
        engine.bandwidthDelay(1000, upload: true),
        const Duration(milliseconds: 500),
      );
    });
  });
}
