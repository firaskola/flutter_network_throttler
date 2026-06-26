import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThrottleStreamTransformer', () {
    test('passes events through when disabled and logs them', () async {
      final controller = ThrottleController(
        profile: const ThrottleProfile(enabled: false),
      );
      final out = Stream.fromIterable([
        1,
        2,
        3,
      ]).transform(ThrottleStreamTransformer<int>(controller, label: 'events'));

      expect(await out.toList(), [1, 2, 3]);
      expect(controller.log, hasLength(3));
      expect(controller.log.every((e) => e.method == 'STRM'), isTrue);
    });

    test('drops events on total packet loss', () async {
      final controller = ThrottleController(
        profile: const ThrottleProfile(
          condition: NetworkCondition(packetLoss: 1.0),
        ),
      );
      final out = Stream.fromIterable([
        1,
        2,
      ]).transform(ThrottleStreamTransformer<int>(controller));

      expect(await out.toList(), isEmpty);
      expect(controller.log.first.outcome, RequestOutcome.failed);
    });

    test('errors the stream when a connection failure is injected', () async {
      final controller = ThrottleController(
        profile: const ThrottleProfile(
          condition: NetworkCondition.perfect,
          failure: FailureInjection(
            enabled: true,
            type: FailureType.noConnection,
            probability: 1.0,
          ),
        ),
      );
      final out = Stream.fromIterable([
        1,
      ]).transform(ThrottleStreamTransformer<int>(controller));

      await expectLater(out.toList(), throwsA(isA<StateError>()));
    });
  });
}
