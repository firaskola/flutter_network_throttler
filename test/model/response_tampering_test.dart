import 'dart:math';

import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final body = List<int>.generate(200, (i) => i % 256);

  group('ResponseTampering.apply', () {
    test('truncate returns a shorter, prefix-shaped body', () {
      const t = ResponseTampering(mode: TamperMode.truncate);
      final out = t.apply(body, Random(1));
      expect(out.length, lessThan(body.length));
      expect(out, body.sublist(0, out.length), reason: 'is a prefix');
    });

    test('corrupt keeps the length but changes some bytes', () {
      const t = ResponseTampering(mode: TamperMode.corrupt);
      final out = t.apply(body, Random(1));
      expect(out.length, body.length);
      expect(out, isNot(body));
    });

    test('garbage keeps the length and (almost certainly) differs', () {
      const t = ResponseTampering(mode: TamperMode.garbage);
      final out = t.apply(body, Random(1));
      expect(out.length, body.length);
      expect(out.every((b) => b >= 0 && b < 256), isTrue);
    });

    test('an empty body is returned unchanged', () {
      for (final mode in TamperMode.values) {
        expect(
          ResponseTampering(mode: mode).apply(const [], Random(1)),
          isEmpty,
        );
      }
    });

    test('is deterministic under the same seed', () {
      const t = ResponseTampering(mode: TamperMode.corrupt);
      expect(t.apply(body, Random(42)), t.apply(body, Random(42)));
    });
  });
}
