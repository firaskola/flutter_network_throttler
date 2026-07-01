import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Wraps every test in this package. Installs a *tolerant* golden comparator so
/// the panel golden catches real UI regressions while shrugging off the few
/// pixels of anti-aliasing / rasteriser noise that differ between host
/// platforms. Only golden comparisons are affected.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final base = goldenFileComparator;
  if (base is LocalFileComparator) {
    goldenFileComparator = _TolerantGoldenComparator(
      base.basedir.resolve('flutter_test_config.dart'),
      tolerance: 0.02,
    );
  }
  await testMain();
}

class _TolerantGoldenComparator extends LocalFileComparator {
  _TolerantGoldenComparator(super.testFile, {required this.tolerance});

  /// Maximum fraction of pixels (0.0–1.0) allowed to differ before failing.
  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) {
      return true;
    }
    await generateFailureOutput(result, golden, basedir);
    return false;
  }
}
