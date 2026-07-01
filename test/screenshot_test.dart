@Tags(['screenshot'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/demo_controller.dart';
import 'support/load_fonts.dart';

// Regenerate the README image with:
//   flutter test --tags screenshot
//
// Unlike the old version, this loads fonts checked into test/fonts/, so it runs
// on every platform (macOS, Linux CI, anywhere) — not just on a Mac.
void main() {
  testWidgets('render the panel to doc/panel.png', (tester) async {
    await loadTestFonts();

    const width = 400.0;
    const height = 2200.0;
    tester.view.physicalSize = const Size(width * 2, height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final controller = buildDemoController();

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: width,
                height: height,
                child: NetworkThrottlerPanel(controller: controller),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('doc').createSync(recursive: true);
      File('doc/panel.png').writeAsBytesSync(data!.buffer.asUint8List());
    });

    expect(File('doc/panel.png').existsSync(), isTrue);
  });
}
