import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThrottleController', () {
    test('toggleEnabled flips and notifies', () {
      final c = ThrottleController();
      var notifications = 0;
      c.addListener(() => notifications++);

      expect(c.enabled, isTrue);
      c.toggleEnabled();
      expect(c.enabled, isFalse);
      expect(notifications, 1);
    });

    test('applyPreset updates condition and preset name', () {
      final c = ThrottleController();
      c.applyPreset(NetworkCondition.twoG);
      expect(c.condition, NetworkCondition.twoG);
      expect(c.presetName, '2G');
      expect(c.enabled, isTrue);
    });

    test('moving a slider marks the profile Custom', () {
      final c = ThrottleController();
      c.setLatency(const Duration(milliseconds: 500));
      expect(c.presetName, 'Custom');
      expect(c.condition.latency, const Duration(milliseconds: 500));
    });

    test('failure mutators update the injection config', () {
      final c = ThrottleController();
      c.toggleFailure();
      c.setFailureType(FailureType.http403);
      c.setFailureProbability(0.25);
      expect(c.failure.enabled, isTrue);
      expect(c.failure.type, FailureType.http403);
      expect(c.failure.probability, 0.25);
    });

    test('add and remove rules', () {
      final c = ThrottleController();
      c.addRule(
        const EndpointRule(pattern: '/v1/feed', action: PassThroughAction()),
      );
      expect(c.rules, hasLength(1));
      c.removeRule(0);
      expect(c.rules, isEmpty);
    });

    test('statusLine reflects paused and active states', () {
      final c = ThrottleController();
      c.applyPreset(NetworkCondition.threeG);
      expect(c.statusLine, '3G · 100ms · 3% loss');
      c.setEnabled(false);
      expect(c.statusLine, 'Paused · pass-through');
    });

    test('log is capped and most-recent-first', () {
      final c = ThrottleController(logCapacity: 2);
      RequestLogEntry entry(String path) => RequestLogEntry(
        method: 'GET',
        url: Uri.parse('https://api.test$path'),
        outcome: RequestOutcome.ok,
        meta: 'ok',
      );
      c.engine.record(entry('/a'));
      c.engine.record(entry('/b'));
      c.engine.record(entry('/c'));
      expect(c.log, hasLength(2));
      expect(c.log.first.path, '/c');
      expect(c.log.last.path, '/b');
    });
  });
}
