@Tags(['screenshot'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

// Real system fonts so rendered text isn't the test framework's box glyphs.
const _sansPath = '/System/Library/Fonts/Supplemental/Arial.ttf';
const _monoPath = '/System/Library/Fonts/Supplemental/Andale Mono.ttf';

Future<void> _loadFont(String family, String path) async {
  final loader = FontLoader(family)
    ..addFont(Future.value(File(path).readAsBytesSync().buffer.asByteData()));
  await loader.load();
}

void main() {
  testWidgets('render the panel to doc/panel.png', (tester) async {
    if (!File(_sansPath).existsSync() || !File(_monoPath).existsSync()) {
      markTestSkipped('System fonts not available; skipping screenshot.');
      return;
    }

    await _loadFont('Arial', _sansPath);
    await _loadFont('monospace', _monoPath);

    const width = 400.0;
    const height = 1640.0;
    tester.view.physicalSize = const Size(width * 2, height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    // A rich, representative state.
    final controller = ThrottleController()
      ..applyPreset(NetworkCondition.threeG)
      ..addRule(
        const EndpointRule(
          method: 'GET',
          pattern: '/v1/feed',
          action: DelayAction(Duration(milliseconds: 800)),
        ),
      )
      ..addRule(
        const EndpointRule(
          method: 'POST',
          pattern: '/v1/upload',
          action: FailAction(FailureType.http500),
        ),
      )
      ..addRule(
        const EndpointRule(pattern: '*.cdn.img/*', action: PassThroughAction()),
      )
      ..toggleFailure()
      ..setFailureProbability(0.15)
      ..seedLog([
        RequestLogEntry(
          method: 'GET',
          url: Uri.parse('https://api.test/v1/feed?page=2'),
          outcome: RequestOutcome.throttled,
          meta: '+842ms',
          appliedDelay: const Duration(milliseconds: 842),
        ),
        RequestLogEntry(
          method: 'POST',
          url: Uri.parse('https://api.test/v1/upload'),
          outcome: RequestOutcome.failed,
          meta: '500',
        ),
        RequestLogEntry(
          method: 'WS↓',
          url: Uri.parse('wss://api.test/socket'),
          outcome: RequestOutcome.ok,
          meta: 'recv',
          kind: RequestKind.webSocket,
        ),
        RequestLogEntry(
          method: 'GET',
          url: Uri.parse('https://api.test/v1/profile/me'),
          outcome: RequestOutcome.ok,
          meta: '118ms',
        ),
      ]);

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Arial', useMaterial3: true),
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
