import 'package:flutter/material.dart';
import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'a request through ThrottleClient appears in the panel live log',
    (tester) async {
      tester.view.physicalSize = const Size(440, 2800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Disabled so the request passes straight through with no timers to
      // pump — we are verifying the wiring, not the delays.
      final controller = ThrottleController(
        profile: const ThrottleProfile(enabled: false),
      );
      final client = ThrottleClient(
        MockClient((_) async => http.Response('{}', 200)),
        controller: controller,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NetworkThrottlerPanel(controller: controller)),
        ),
      );

      expect(find.text('No requests captured yet.'), findsOneWidget);

      await client.get(Uri.parse('https://api.example.com/v1/profile/me'));
      await tester.pump();

      expect(find.text('/v1/profile/me'), findsOneWidget);
      expect(controller.log, hasLength(1));
      expect(controller.log.first.outcome, RequestOutcome.ok);
    },
  );
}
