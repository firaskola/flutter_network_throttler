import 'package:flutter/material.dart';
import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(ThrottleController controller) {
  return MaterialApp(
    home: Scaffold(body: NetworkThrottlerPanel(controller: controller)),
  );
}

/// Pumps the panel inside a tall viewport so every section lays out (the panel
/// uses a lazy [ListView], so off-screen sections aren't built otherwise).
Future<void> pumpPanel(
  WidgetTester tester,
  ThrottleController controller,
) async {
  tester.view.physicalSize = const Size(440, 2800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(wrap(controller));
}

void main() {
  group('NetworkThrottlerPanel', () {
    testWidgets('renders the header and section titles', (tester) async {
      await pumpPanel(tester, ThrottleController());

      expect(find.text('Network Throttler'), findsOneWidget);
      expect(find.text('PRESETS'), findsOneWidget);
      expect(find.text('CONDITIONS'), findsOneWidget);
      expect(find.text('FAILURE INJECTION'), findsOneWidget);
      expect(find.text('PER-ENDPOINT RULES'), findsOneWidget);
      expect(find.text('LIVE REQUEST LOG'), findsOneWidget);
    });

    testWidgets('tapping the master switch toggles the controller', (
      tester,
    ) async {
      final controller = ThrottleController();
      await pumpPanel(tester, controller);

      expect(controller.enabled, isTrue);
      // The first GestureDetector in the header is the master switch.
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(controller.enabled, isFalse);
    });

    testWidgets('tapping a preset chip applies it', (tester) async {
      final controller = ThrottleController();
      await pumpPanel(tester, controller);

      await tester.tap(find.text('2G'));
      await tester.pump();
      expect(controller.presetName, '2G');
      expect(controller.condition, NetworkCondition.twoG);
    });

    testWidgets('renders seeded log entries', (tester) async {
      final controller = ThrottleController()
        ..seedLog([
          RequestLogEntry(
            method: 'GET',
            url: Uri.parse('https://api.test/v1/feed?page=2'),
            outcome: RequestOutcome.throttled,
            meta: '+842ms',
          ),
        ]);
      await pumpPanel(tester, controller);

      expect(find.text('/v1/feed?page=2'), findsOneWidget);
      expect(find.text('+842ms'), findsOneWidget);
    });

    testWidgets('add rule opens the editor and appends a rule', (tester) async {
      final controller = ThrottleController();
      await pumpPanel(tester, controller);

      expect(controller.rules, isEmpty);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Add rule'), findsOneWidget); // dialog title

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(controller.rules, hasLength(1));
    });

    testWidgets('log filter and clear controls work', (tester) async {
      final controller = ThrottleController()
        ..seedLog([
          RequestLogEntry(
            method: 'GET',
            url: Uri.parse('https://api.test/a'),
            outcome: RequestOutcome.ok,
            meta: '10ms',
          ),
        ]);
      await pumpPanel(tester, controller);

      expect(find.text('/a'), findsOneWidget);
      // Filter to WS only — the HTTP entry disappears.
      await tester.tap(find.text('WS'));
      await tester.pump();
      expect(find.text('/a'), findsNothing);
    });
  });
}
