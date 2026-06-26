import 'package:flutter/material.dart';
import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NetworkThrottlerButton', () {
    testWidgets('shows a FAB in debug mode and opens the panel', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 2800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = ThrottleController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: NetworkThrottlerButton(
              controller: controller,
            ),
          ),
        ),
      );

      // Tests run in debug mode, so the launcher is visible.
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // The panel is now on screen.
      expect(find.text('Network Throttler'), findsOneWidget);
      expect(find.text('CONDITIONS'), findsOneWidget);
    });

    testWidgets('uses a custom child trigger when provided', (tester) async {
      final controller = ThrottleController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkThrottlerButton(
              controller: controller,
              child: const Text('Open throttler'),
            ),
          ),
        ),
      );

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Open throttler'), findsOneWidget);
    });

    testWidgets('page presentation pushes a route with a back button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 2800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = ThrottleController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: NetworkThrottlerButton(
              controller: controller,
              presentation: ThrottlerPresentation.page,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // The panel is on a full page now, with a back button to pop it.
      expect(find.byType(NetworkThrottlerPage), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(NetworkThrottlerPage), findsNothing);
    });
  });
}
