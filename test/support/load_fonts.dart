import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the checked-in Roboto fonts (`test/fonts/`, Apache-2.0) so rendered
/// widgets show real glyphs instead of the test framework's placeholder boxes —
/// on *every* platform, not just macOS.
///
/// Roboto is also registered under the `monospace` family the panel asks for
/// (it isn't truly monospaced, but it renders cleanly and deterministically).
Future<void> loadTestFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      // Read synchronously: flutter_test drives a fake clock, so awaiting real
      // async file I/O in a test body hangs. A completed Future does not.
      final bytes = File('test/fonts/$file').readAsBytesSync();
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  const faces = <String>[
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ];
  await load('Roboto', faces);
  await load('monospace', faces);
}
