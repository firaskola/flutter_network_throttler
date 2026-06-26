import 'dart:async';

import '../engine/throttle_controller.dart';
import '../model/network_condition.dart';

/// A single timed step in a [ThrottleScenario]: wait [at] (measured from the
/// scenario start), then run [apply] against the controller.
class ScenarioStep {
  /// Creates a step that runs [apply] at offset [at] from scenario start.
  const ScenarioStep(this.at, this.apply, {this.label});

  /// Offset from the scenario's start at which this step runs.
  final Duration at;

  /// The mutation to perform on the controller.
  final void Function(ThrottleController controller) apply;

  /// Optional human-readable description, surfaced via [ThrottleScenario.onStep].
  final String? label;
}

/// Scripts a timeline of network conditions against a [ThrottleController] —
/// "go offline for 5s, then recover to 3G", flaky bursts, gradual degradation —
/// so you can reproduce field issues and drive tests deterministically.
///
/// ```dart
/// final scenario = ThrottleScenario([
///   ScenarioStep(Duration.zero, (c) => c.applyPreset(NetworkCondition.offline)),
///   ScenarioStep(const Duration(seconds: 5),
///       (c) => c.applyPreset(NetworkCondition.threeG)),
/// ]);
/// scenario.start(controller);
/// ```
///
/// Set [loop] to repeat the timeline. Call [stop] (or [dispose]) to cancel.
class ThrottleScenario {
  /// Creates a scenario from an ordered (or unordered) list of [steps].
  ThrottleScenario(List<ScenarioStep> steps, {this.loop = false})
    : steps = List<ScenarioStep>.unmodifiable(
        [...steps]..sort((a, b) => a.at.compareTo(b.at)),
      );

  /// Builds a scenario that goes offline immediately and recovers to [recover]
  /// (default 3G) after [duration] — the canonical "offline blip" test.
  factory ThrottleScenario.offlineFor(
    Duration duration, {
    NetworkCondition recover = NetworkCondition.threeG,
  }) {
    return ThrottleScenario([
      ScenarioStep(
        Duration.zero,
        (c) => c.applyPreset(NetworkCondition.offline),
        label: 'offline',
      ),
      ScenarioStep(duration, (c) => c.applyPreset(recover), label: 'recover'),
    ]);
  }

  /// The steps, sorted by [ScenarioStep.at].
  final List<ScenarioStep> steps;

  /// Whether to restart the timeline after the last step.
  final bool loop;

  /// Invoked as each step runs, with its [ScenarioStep.label] (or `''`).
  void Function(String label)? onStep;

  final List<Timer> _timers = <Timer>[];
  bool _running = false;

  /// Whether the scenario is currently playing.
  bool get isRunning => _running;

  /// Starts (or restarts) the scenario against [controller].
  void start(ThrottleController controller) {
    stop();
    _running = true;
    _schedule(controller);
  }

  void _schedule(ThrottleController controller) {
    if (steps.isEmpty) {
      _running = false;
      return;
    }
    for (final step in steps) {
      _timers.add(
        Timer(step.at, () {
          if (!_running) return;
          step.apply(controller);
          onStep?.call(step.label ?? '');
        }),
      );
    }
    if (loop) {
      final period = steps.last.at + const Duration(milliseconds: 1);
      _timers.add(
        Timer(period, () {
          if (!_running) return;
          _clearTimers();
          _schedule(controller);
        }),
      );
    }
  }

  /// Stops the scenario and cancels any pending steps.
  void stop() {
    _running = false;
    _clearTimers();
  }

  void _clearTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  /// Cancels the scenario; alias for [stop].
  void dispose() => stop();
}
