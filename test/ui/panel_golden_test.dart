@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/demo_controller.dart';
import '../support/load_fonts.dart';

// Golden regression test for the whole panel. Regenerate the baseline after an
// intentional UI change with:
//   flutter test --tags golden --update-goldens
void main() {
  testWidgets('NetworkThrottlerPanel matches its golden', (tester) async {
    await loadTestFonts();

    const width = 400.0;
    const height = 2320.0;
    tester.view.physicalSize = const Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: width,
              height: height,
              child: NetworkThrottlerPanel(controller: buildDemoController()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(find.byKey(key), matchesGoldenFile('goldens/panel.png'));
  });
}
