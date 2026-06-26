import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStorage implements ThrottleStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String data) async => value = data;
}

void main() {
  group('persistence', () {
    test('saves profile changes to storage', () async {
      final storage = _MemoryStorage();
      final c = ThrottleController(storage: storage);
      await c.loaded;

      c.applyPreset(NetworkCondition.twoG);
      await Future<void>.delayed(Duration.zero); // let the microtask save flush

      expect(storage.value, isNotNull);
      expect(storage.value, contains('2G'));
    });

    test('restores profile and custom presets on construction', () async {
      final storage = _MemoryStorage();
      final first = ThrottleController(storage: storage);
      await first.loaded;
      first
        ..applyPreset(NetworkCondition.twoG)
        ..setLatency(const Duration(milliseconds: 321))
        ..saveCurrentAsPreset('My link');
      await Future<void>.delayed(Duration.zero);

      final restored = ThrottleController(storage: storage);
      await restored.loaded;

      expect(restored.condition.latency, const Duration(milliseconds: 321));
      expect(restored.customPresets.map((c) => c.name), contains('My link'));
      expect(restored.presets.map((c) => c.name), contains('My link'));
    });
  });

  group('saved presets', () {
    test('saveCurrentAsPreset adds and activates a preset', () {
      final c = ThrottleController()..setLatency(const Duration(seconds: 1));
      c.saveCurrentAsPreset('Slow');
      expect(c.presetName, 'Slow');
      expect(c.customPresets.single.name, 'Slow');
    });

    test('deletePreset removes it', () {
      final c = ThrottleController()..saveCurrentAsPreset('Temp');
      expect(c.customPresets, hasLength(1));
      c.deletePreset('Temp');
      expect(c.customPresets, isEmpty);
    });
  });

  group('capture control', () {
    test('paused capture drops new log entries', () {
      final c = ThrottleController()..setCapturing(false);
      c.engine.record(
        RequestLogEntry(
          method: 'GET',
          url: Uri.parse('https://api.test/x'),
          outcome: RequestOutcome.ok,
          meta: 'ok',
        ),
      );
      expect(c.log, isEmpty);
    });
  });

  group('metrics', () {
    test('summarises the log', () {
      final c = ThrottleController()
        ..seedLog([
          RequestLogEntry(
            method: 'GET',
            url: Uri.parse('https://api.test/a'),
            outcome: RequestOutcome.throttled,
            meta: '+100ms',
            appliedDelay: const Duration(milliseconds: 100),
          ),
          RequestLogEntry(
            method: 'GET',
            url: Uri.parse('https://api.test/b'),
            outcome: RequestOutcome.failed,
            meta: '500',
          ),
        ]);
      final m = c.metrics;
      expect(m.total, 2);
      expect(m.failed, 1);
      expect(m.throttled, 1);
      expect(m.failureRate, 0.5);
      expect(m.averageAddedDelay, const Duration(milliseconds: 100));
    });
  });
}
