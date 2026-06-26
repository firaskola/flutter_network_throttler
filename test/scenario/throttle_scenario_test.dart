import 'package:fake_async/fake_async.dart';
import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThrottleScenario', () {
    test('runs steps at their scheduled offsets', () {
      fakeAsync((async) {
        final controller = ThrottleController();
        final scenario = ThrottleScenario([
          ScenarioStep(
            Duration.zero,
            (c) => c.applyPreset(NetworkCondition.offline),
          ),
          ScenarioStep(
            const Duration(seconds: 5),
            (c) => c.applyPreset(NetworkCondition.fourG),
          ),
        ])..start(controller);

        async.elapse(Duration.zero);
        expect(controller.condition, NetworkCondition.offline);

        async.elapse(const Duration(seconds: 4));
        expect(controller.condition, NetworkCondition.offline);

        async.elapse(const Duration(seconds: 1));
        expect(controller.condition, NetworkCondition.fourG);
        expect(scenario.isRunning, isTrue);
        scenario.stop();
      });
    });

    test('offlineFor goes offline then recovers', () {
      fakeAsync((async) {
        final controller = ThrottleController();
        ThrottleScenario.offlineFor(
          const Duration(seconds: 3),
          recover: NetworkCondition.wifi,
        ).start(controller);

        async.elapse(Duration.zero);
        expect(controller.condition.isOffline, isTrue);

        async.elapse(const Duration(seconds: 3));
        expect(controller.condition, NetworkCondition.wifi);
      });
    });

    test('stop cancels pending steps', () {
      fakeAsync((async) {
        final controller = ThrottleController();
        final scenario = ThrottleScenario([
          ScenarioStep(
            const Duration(seconds: 2),
            (c) => c.applyPreset(NetworkCondition.offline),
          ),
        ])..start(controller);

        async.elapse(const Duration(seconds: 1));
        scenario.stop();
        async.elapse(const Duration(seconds: 5));

        expect(controller.condition, NetworkCondition.threeG); // unchanged
        expect(scenario.isRunning, isFalse);
      });
    });

    test('loop restarts the timeline', () {
      fakeAsync((async) {
        final controller = ThrottleController();
        var runs = 0;
        final scenario = ThrottleScenario([
          ScenarioStep(const Duration(seconds: 1), (_) => runs++),
        ], loop: true)..start(controller);

        async.elapse(const Duration(seconds: 1));
        expect(runs, 1);
        async.elapse(const Duration(milliseconds: 1100));
        expect(runs, 2);
        scenario.stop();
      });
    });
  });
}
