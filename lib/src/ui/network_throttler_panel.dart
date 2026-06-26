import 'package:flutter/material.dart';

import '../engine/throttle_controller.dart';
import '../model/endpoint_rule.dart';
import '../model/failure.dart';
import '../model/network_condition.dart';
import '../model/request_log.dart';
import 'throttler_theme.dart';

/// A debug control panel for a [ThrottleController], mirroring the Network
/// Throttler design: a master switch, preset chips, condition sliders, failure
/// injection, per-endpoint rules, and a live request log.
///
/// Drop it anywhere in a debug build — embedded in a page, a drawer, or shown
/// as a modal sheet via [showNetworkThrottlerPanel]:
///
/// ```dart
/// NetworkThrottlerPanel(controller: myController)
/// ```
///
/// The panel fills the available width and scrolls vertically; it does not
/// impose the host app's theme.
class NetworkThrottlerPanel extends StatelessWidget {
  /// Creates a panel bound to [controller].
  const NetworkThrottlerPanel({super.key, required this.controller});

  /// The controller this panel reads and mutates.
  final ThrottleController controller;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ThrottlerTokens.background,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final enabled = controller.enabled;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PanelHeader(controller: controller),
              Expanded(
                child: IgnorePointer(
                  ignoring: !enabled,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: enabled ? 1 : 0.45,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 28),
                      children: [
                        _PresetsSection(controller: controller),
                        _ConditionsSection(controller: controller),
                        _FailureInjectionSection(controller: controller),
                        _RulesSection(controller: controller),
                        _LiveLogSection(controller: controller),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Presents [NetworkThrottlerPanel] as a modal bottom sheet over the current
/// screen — a convenient way to surface it from a debug button.
///
/// Dismissed by dragging the handle down or tapping the scrim. For a full-screen
/// route with a back button instead, use [showNetworkThrottlerPage].
Future<void> showNetworkThrottlerPanel(
  BuildContext context,
  ThrottleController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: ThrottlerTokens.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.92,
        child: NetworkThrottlerPanel(controller: controller),
      );
    },
  );
}

/// A full-screen page wrapping [NetworkThrottlerPanel] in a [Scaffold] with an
/// app bar — so when pushed onto a [Navigator] it gets a back button for free.
///
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(builder: (_) => NetworkThrottlerPage(controller: c)),
/// );
/// ```
///
/// Or use the [showNetworkThrottlerPage] helper.
class NetworkThrottlerPage extends StatelessWidget {
  /// Creates a page bound to [controller].
  const NetworkThrottlerPage({super.key, required this.controller, this.title});

  /// The controller the panel reads and mutates.
  final ThrottleController controller;

  /// Optional app-bar title. The panel's own header already shows the name, so
  /// this defaults to empty (just a back button).
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThrottlerTokens.background,
      appBar: AppBar(
        title: title == null ? null : Text(title!),
        backgroundColor: ThrottlerTokens.background,
        foregroundColor: ThrottlerTokens.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: NetworkThrottlerPanel(controller: controller),
    );
  }
}

/// Pushes a [NetworkThrottlerPage] onto the navigator. The page shows a standard
/// back button to pop it.
Future<void> showNetworkThrottlerPage(
  BuildContext context,
  ThrottleController controller, {
  String? title,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          NetworkThrottlerPage(controller: controller, title: title),
    ),
  );
}

// --- header ----------------------------------------------------------------

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.controller});

  final ThrottleController controller;

  @override
  Widget build(BuildContext context) {
    final on = controller.enabled;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: const BoxDecoration(
        color: ThrottlerTokens.background,
        border: Border(bottom: BorderSide(color: ThrottlerTokens.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: on ? const Color(0xFFE7F0FE) : const Color(0xFFECEEF1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.wifi_rounded,
              size: 22,
              color: on ? ThrottlerTokens.accent : ThrottlerTokens.muted,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Network Throttler',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: ThrottlerTokens.ink,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  controller.statusLine,
                  style: ThrottlerTokens.mono(
                    size: 12,
                    weight: FontWeight.w500,
                    color: on ? ThrottlerTokens.green : ThrottlerTokens.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _PillSwitch(
            value: on,
            activeColor: ThrottlerTokens.green,
            width: 50,
            height: 30,
            onChanged: (_) => controller.toggleEnabled(),
          ),
        ],
      ),
    );
  }
}

// --- presets ---------------------------------------------------------------

class _PresetsSection extends StatelessWidget {
  const _PresetsSection({required this.controller});

  final ThrottleController controller;

  bool _isCustom(NetworkCondition preset) =>
      !NetworkCondition.presets.contains(preset);

  Future<void> _saveCurrent(BuildContext context) async {
    final name = await _promptForName(
      context,
      title: 'Save current as preset',
      hint: 'e.g. Office Wi-Fi',
    );
    if (name != null && name.trim().isNotEmpty) {
      controller.saveCurrentAsPreset(name.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final presets = controller.presets;
    return _Section(
      title: 'Presets',
      action: _SectionAction(
        label: 'Save current',
        onTap: () => _saveCurrent(context),
      ),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: presets.length,
          separatorBuilder: (_, _) => const SizedBox(width: 9),
          itemBuilder: (context, i) {
            final preset = presets[i];
            return _PresetChip(
              preset: preset,
              active: controller.presetName == preset.name,
              deletable: _isCustom(preset),
              onTap: () => controller.applyPreset(preset),
              onDelete: () => controller.deletePreset(preset.name),
            );
          },
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.preset,
    required this.active,
    required this.onTap,
    this.deletable = false,
    this.onDelete,
  });

  final NetworkCondition preset;
  final bool active;
  final bool deletable;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  Color get _dotColor {
    if (preset.isOffline) return ThrottlerTokens.secondary;
    if (preset.packetLoss >= 0.05) return ThrottlerTokens.red;
    if (preset.packetLoss > 0) return ThrottlerTokens.amber;
    return ThrottlerTokens.green;
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await _confirm(
      context,
      title: 'Delete preset?',
      message: 'Remove the saved preset "${preset.name}".',
    );
    if (ok) onDelete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: deletable ? () => _confirmDelete(context) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? ThrottlerTokens.accent : ThrottlerTokens.card,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: active ? ThrottlerTokens.accent : ThrottlerTokens.chipBorder,
            width: 1.5,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: ThrottlerTokens.accent.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? Colors.white : _dotColor,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              preset.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : ThrottlerTokens.body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- conditions ------------------------------------------------------------

class _ConditionsSection extends StatelessWidget {
  const _ConditionsSection({required this.controller});

  final ThrottleController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller.condition;
    return _Section(
      title: 'Conditions',
      child: _Card(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            _ConditionSlider(
              label: 'Latency',
              color: ThrottlerTokens.accent,
              valueText: '${c.latency.inMilliseconds} ms',
              value: c.latency.inMilliseconds.toDouble(),
              min: 0,
              max: 2000,
              divisions: 400,
              onChanged: (v) =>
                  controller.setLatency(Duration(milliseconds: v.round())),
            ),
            const _RowDivider(),
            _ConditionSlider(
              label: 'Jitter',
              color: ThrottlerTokens.purple,
              valueText: '± ${c.latencyJitter.inMilliseconds} ms',
              value: c.latencyJitter.inMilliseconds.toDouble(),
              min: 0,
              max: 500,
              divisions: 100,
              onChanged: (v) =>
                  controller.setJitter(Duration(milliseconds: v.round())),
            ),
            const _RowDivider(),
            _ConditionSlider(
              label: 'Bandwidth cap',
              color: ThrottlerTokens.teal,
              valueText: _formatBandwidth(c.bandwidthKbps),
              value: c.bandwidthKbps.toDouble().clamp(0, 30000),
              min: 0,
              max: 30000,
              divisions: 1500,
              onChanged: (v) => controller.setBandwidth(v.round()),
            ),
            const _RowDivider(),
            _ConditionSlider(
              label: 'Packet loss',
              color: ThrottlerTokens.amber,
              valueText: '${(c.packetLoss * 100).round()} %',
              value: (c.packetLoss * 100).clamp(0, 100),
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: (v) => controller.setPacketLoss(v / 100),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConditionSlider extends StatelessWidget {
  const _ConditionSlider({
    required this.label,
    required this.color,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ThrottlerTokens.ink,
                ),
              ),
              const Spacer(),
              Text(valueText, style: ThrottlerTokens.mono(color: color)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: color,
              inactiveTrackColor: ThrottlerTokens.trackInactive,
              thumbColor: Colors.white,
              overlayColor: color.withValues(alpha: 0.14),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// --- failure injection -----------------------------------------------------

class _FailureInjectionSection extends StatelessWidget {
  const _FailureInjectionSection({required this.controller});

  final ThrottleController controller;

  @override
  Widget build(BuildContext context) {
    final failure = controller.failure;
    return _Section(
      title: 'Failure Injection',
      child: _Card(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: ThrottlerTokens.redTint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: ThrottlerTokens.red,
                  ),
                ),
                const SizedBox(width: 9),
                const Text(
                  'Inject errors',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ThrottlerTokens.ink,
                  ),
                ),
                const Spacer(),
                _PillSwitch(
                  value: failure.enabled,
                  activeColor: ThrottlerTokens.red,
                  width: 46,
                  height: 27,
                  onChanged: (_) => controller.toggleFailure(),
                ),
              ],
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: failure.enabled ? 1 : 0.4,
              child: IgnorePointer(
                ignoring: !failure.enabled,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Error type',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ThrottlerTokens.secondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _FailureTypeGrid(controller: controller),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Text(
                            'Probability',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ThrottlerTokens.ink,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(failure.probability * 100).round()} % of requests',
                            style: ThrottlerTokens.mono(
                              color: ThrottlerTokens.red,
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          activeTrackColor: ThrottlerTokens.red,
                          inactiveTrackColor: ThrottlerTokens.trackInactive,
                          thumbColor: Colors.white,
                          overlayColor: ThrottlerTokens.red.withValues(
                            alpha: 0.14,
                          ),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 9,
                          ),
                        ),
                        child: Slider(
                          value: (failure.probability * 100).clamp(0, 100),
                          min: 0,
                          max: 100,
                          divisions: 100,
                          onChanged: (v) =>
                              controller.setFailureProbability(v / 100),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureTypeGrid extends StatelessWidget {
  const _FailureTypeGrid({required this.controller});

  final ThrottleController controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.failure.type;
    final types = FailureType.values;
    return Column(
      children: [
        for (var row = 0; row < types.length; row += 2)
          Padding(
            padding: EdgeInsets.only(bottom: row + 2 < types.length ? 8 : 0),
            child: Row(
              children: [
                Expanded(
                  child: _FailureTypeChip(
                    type: types[row],
                    selected: selected == types[row],
                    onTap: () => controller.setFailureType(types[row]),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: row + 1 < types.length
                      ? _FailureTypeChip(
                          type: types[row + 1],
                          selected: selected == types[row + 1],
                          onTap: () =>
                              controller.setFailureType(types[row + 1]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FailureTypeChip extends StatelessWidget {
  const _FailureTypeChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final FailureType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? ThrottlerTokens.redTint : const Color(0xFFFAFBFC),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? ThrottlerTokens.red : ThrottlerTokens.border,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              type.code,
              style: ThrottlerTokens.mono(
                color: selected
                    ? ThrottlerTokens.redInk
                    : const Color(0xFF5B6270),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              type.label,
              style: TextStyle(
                fontSize: 11,
                color:
                    (selected
                            ? ThrottlerTokens.redInk
                            : const Color(0xFF5B6270))
                        .withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- per-endpoint rules ----------------------------------------------------

class _RulesSection extends StatelessWidget {
  const _RulesSection({required this.controller});

  final ThrottleController controller;

  Future<void> _addRule(BuildContext context) async {
    final rule = await showRuleEditor(context);
    if (rule != null && !rule.isDelete) controller.addRule(rule.copyWith());
  }

  Future<void> _editRule(BuildContext context, int index) async {
    final result = await showRuleEditor(
      context,
      initial: controller.rules[index],
    );
    if (result == null) return;
    if (result.isDelete) {
      controller.removeRule(index);
    } else {
      controller.updateRule(index, result.copyWith());
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = controller.rules;
    return _Section(
      title: 'Per-endpoint rules',
      action: _SectionAction(label: 'Add', onTap: () => _addRule(context)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: rules.isEmpty
            ? const _EmptyHint('No rules yet — tap Add to create one.')
            : Column(
                children: [
                  for (var i = 0; i < rules.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i < rules.length - 1 ? 8 : 0,
                      ),
                      child: _RuleRow(
                        rule: rules[i],
                        onTap: () => _editRule(context, i),
                        onRemove: () => controller.removeRule(i),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.rule,
    required this.onRemove,
    required this.onTap,
  });

  final EndpointRule rule;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  Color get _actionColor {
    switch (rule.action.kind) {
      case RuleKind.fail:
        return ThrottlerTokens.red;
      case RuleKind.pass:
        return ThrottlerTokens.green;
      case RuleKind.slow:
        return ThrottlerTokens.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final method = rule.method ?? 'ANY';
    final methodColor = ThrottlerTokens.methodColor(method);
    return GestureDetector(
      onTap: onTap,
      child: _Card(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        radius: 14,
        child: Row(
          children: [
            _Badge(text: method, color: methodColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                rule.pattern,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ThrottlerTokens.mono(
                  size: 12,
                  weight: FontWeight.w500,
                  color: ThrottlerTokens.ink,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _Badge(text: rule.action.label, color: _actionColor, mono: true),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: ThrottlerTokens.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- live log --------------------------------------------------------------

enum _LogFilter { all, http, ws, failed }

class _LiveLogSection extends StatefulWidget {
  const _LiveLogSection({required this.controller});

  final ThrottleController controller;

  @override
  State<_LiveLogSection> createState() => _LiveLogSectionState();
}

class _LiveLogSectionState extends State<_LiveLogSection> {
  _LogFilter _filter = _LogFilter.all;

  bool _matches(RequestLogEntry e) {
    switch (_filter) {
      case _LogFilter.all:
        return true;
      case _LogFilter.http:
        return e.kind == RequestKind.http;
      case _LogFilter.ws:
        return e.kind == RequestKind.webSocket;
      case _LogFilter.failed:
        return e.outcome == RequestOutcome.failed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final log = controller.log.where(_matches).toList();
    return _Section(
      title: 'Live request log',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconAction(
            icon: controller.capturing
                ? Icons.pause_rounded
                : Icons.fiber_manual_record_rounded,
            color: controller.capturing
                ? ThrottlerTokens.secondary
                : ThrottlerTokens.green,
            tooltip: controller.capturing ? 'Pause capture' : 'Resume capture',
            onTap: controller.toggleCapturing,
          ),
          const SizedBox(width: 6),
          _IconAction(
            icon: Icons.delete_outline_rounded,
            color: ThrottlerTokens.secondary,
            tooltip: 'Clear log',
            onTap: controller.clearLog,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MetricsStrip(metrics: controller.metrics),
            const SizedBox(height: 10),
            _LogFilterBar(
              filter: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
            const SizedBox(height: 10),
            _Card(
              padding: EdgeInsets.zero,
              child: log.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: _EmptyHint('No requests captured yet.'),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < log.length; i++)
                          _LogRow(
                            entry: log[i],
                            showDivider: i < log.length - 1,
                            onTap: () => _showInspector(context, log[i]),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsStrip extends StatelessWidget {
  const _MetricsStrip({required this.metrics});

  final ThrottleMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final avgMs = metrics.averageAddedDelay.inMilliseconds;
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 14,
      child: Row(
        children: [
          _Metric(label: 'requests', value: '${metrics.total}'),
          _MetricDivider(),
          _Metric(
            label: 'failed',
            value: '${(metrics.failureRate * 100).round()}%',
            color: metrics.failed > 0 ? ThrottlerTokens.red : null,
          ),
          _MetricDivider(),
          _Metric(label: 'avg added', value: '+${avgMs}ms'),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: ThrottlerTokens.mono(
              size: 15,
              weight: FontWeight.w700,
              color: color ?? ThrottlerTokens.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              color: ThrottlerTokens.label,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 26, color: ThrottlerTokens.divider);
}

class _LogFilterBar extends StatelessWidget {
  const _LogFilterBar({required this.filter, required this.onChanged});

  final _LogFilter filter;
  final ValueChanged<_LogFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = {
      _LogFilter.all: 'All',
      _LogFilter.http: 'HTTP',
      _LogFilter.ws: 'WS',
      _LogFilter.failed: 'Failed',
    };
    return Row(
      children: [
        for (final entry in labels.entries) ...[
          _FilterChip(
            label: entry.value,
            selected: filter == entry.key,
            onTap: () => onChanged(entry.key),
          ),
          const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? ThrottlerTokens.ink : ThrottlerTokens.card,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? ThrottlerTokens.ink : ThrottlerTokens.chipBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : ThrottlerTokens.body,
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({
    required this.entry,
    required this.showDivider,
    required this.onTap,
  });

  final RequestLogEntry entry;
  final bool showDivider;
  final VoidCallback onTap;

  Color get _color {
    switch (entry.outcome) {
      case RequestOutcome.ok:
        return ThrottlerTokens.green;
      case RequestOutcome.throttled:
        return ThrottlerTokens.amber;
      case RequestOutcome.failed:
        return ThrottlerTokens.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: ThrottlerTokens.divider))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _color,
                boxShadow: [
                  BoxShadow(
                    color: _color.withValues(alpha: 0.2),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 46,
              child: Text(
                entry.method,
                style: ThrottlerTokens.mono(
                  size: 10,
                  weight: FontWeight.w700,
                  color: entry.kind == RequestKind.webSocket
                      ? ThrottlerTokens.purple
                      : ThrottlerTokens.label,
                ),
              ),
            ),
            Expanded(
              child: Text(
                entry.path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ThrottlerTokens.mono(
                  size: 12,
                  weight: FontWeight.w500,
                  color: ThrottlerTokens.body,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              entry.meta,
              style: ThrottlerTokens.mono(size: 11.5, color: _color),
            ),
          ],
        ),
      ),
    );
  }
}

// --- shared building blocks ------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              children: [
                Text(title.toUpperCase(), style: ThrottlerTokens.sectionLabel),
                const Spacer(),
                ?action,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SectionAction extends StatelessWidget {
  const _SectionAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.add_rounded,
            size: 14,
            color: ThrottlerTokens.accent,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ThrottlerTokens.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: ThrottlerTokens.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: ThrottlerTokens.border),
      ),
      child: child,
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: ThrottlerTokens.divider,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color, this.mono = true});

  final String text;
  final Color color;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: ThrottlerTokens.mono(
          size: 10.5,
          weight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, color: ThrottlerTokens.muted),
    );
  }
}

/// A pill-style toggle matching the design's switches.
class _PillSwitch extends StatelessWidget {
  const _PillSwitch({
    required this.value,
    required this.activeColor,
    required this.width,
    required this.height,
    required this.onChanged,
  });

  final bool value;
  final Color activeColor;
  final double width;
  final double height;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final knob = height - 6;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        height: height,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? activeColor : ThrottlerTokens.switchOff,
          borderRadius: BorderRadius.circular(99),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: knob,
            height: knob,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 3)],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatBandwidth(int kbps) {
  if (kbps <= 0) return 'blocked';
  if (kbps >= 1000) {
    final mbps = kbps / 1000;
    final text = kbps % 1000 == 0
        ? mbps.toStringAsFixed(0)
        : mbps.toStringAsFixed(1);
    return '$text Mbps';
  }
  return '$kbps kbps';
}

// --- dialogs ---------------------------------------------------------------

Future<String?> _promptForName(
  BuildContext context, {
  required String title,
  String? hint,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}

void _showInspector(BuildContext context, RequestLogEntry entry) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: ThrottlerTokens.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Badge(
                text: entry.method,
                color: ThrottlerTokens.methodColor(entry.method),
              ),
              const SizedBox(width: 10),
              Text(
                entry.outcome.name,
                style: ThrottlerTokens.mono(
                  size: 13,
                  color: switch (entry.outcome) {
                    RequestOutcome.ok => ThrottlerTokens.green,
                    RequestOutcome.throttled => ThrottlerTokens.amber,
                    RequestOutcome.failed => ThrottlerTokens.red,
                  },
                ),
              ),
              const Spacer(),
              Text(entry.meta, style: ThrottlerTokens.mono(size: 13)),
            ],
          ),
          const SizedBox(height: 16),
          _InspectRow(label: 'URL', value: entry.url.toString()),
          _InspectRow(
            label: 'Kind',
            value: entry.kind == RequestKind.webSocket ? 'WebSocket' : 'HTTP',
          ),
          if (entry.appliedDelay != null)
            _InspectRow(
              label: 'Added delay',
              value: '${entry.appliedDelay!.inMilliseconds} ms',
            ),
        ],
      ),
    ),
  );
}

class _InspectRow extends StatelessWidget {
  const _InspectRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: ThrottlerTokens.sectionLabel),
          const SizedBox(height: 3),
          SelectableText(
            value,
            style: ThrottlerTokens.mono(
              size: 13,
              weight: FontWeight.w500,
              color: ThrottlerTokens.body,
            ),
          ),
        ],
      ),
    );
  }
}

// --- rule editor -----------------------------------------------------------

/// The result of editing a rule: either a [rule] to save, or a delete request.
class RuleEditResult extends EndpointRule {
  const RuleEditResult._delete()
    : isDelete = true,
      super(pattern: '', action: const PassThroughAction());

  RuleEditResult.save(EndpointRule rule)
    : isDelete = false,
      super(method: rule.method, pattern: rule.pattern, action: rule.action);

  /// Whether the user asked to delete the rule.
  final bool isDelete;
}

/// Shows the rule editor. Returns the saved/edited [EndpointRule] (which may be
/// a [RuleEditResult] with `isDelete == true`), or `null` if cancelled.
Future<RuleEditResult?> showRuleEditor(
  BuildContext context, {
  EndpointRule? initial,
}) {
  return showDialog<RuleEditResult>(
    context: context,
    builder: (context) => _RuleEditorDialog(initial: initial),
  );
}

class _RuleEditorDialog extends StatefulWidget {
  const _RuleEditorDialog({this.initial});

  final EndpointRule? initial;

  @override
  State<_RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<_RuleEditorDialog> {
  static const _methods = ['ANY', 'GET', 'POST', 'PUT', 'DELETE', 'WS'];

  late String _method;
  late TextEditingController _pattern;
  late RuleKind _kind;
  late int _delayMs;
  late FailureType _failType;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _method = r?.method ?? 'ANY';
    _pattern = TextEditingController(text: r?.pattern ?? '/v1/');
    final action = r?.action;
    _kind = action?.kind ?? RuleKind.slow;
    _delayMs = action is DelayAction ? action.extra.inMilliseconds : 500;
    _failType = action is FailAction ? action.type : FailureType.http500;
  }

  @override
  void dispose() {
    _pattern.dispose();
    super.dispose();
  }

  RuleAction _buildAction() {
    switch (_kind) {
      case RuleKind.slow:
        return DelayAction(Duration(milliseconds: _delayMs));
      case RuleKind.fail:
        return FailAction(_failType);
      case RuleKind.pass:
        return const PassThroughAction();
    }
  }

  void _save() {
    final rule = EndpointRule(
      method: _method == 'ANY' ? null : _method,
      pattern: _pattern.text.trim(),
      action: _buildAction(),
    );
    Navigator.of(context).pop(RuleEditResult.save(rule));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add rule' : 'Edit rule'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Method'),
              items: [
                for (final m in _methods)
                  DropdownMenuItem(value: m, child: Text(m)),
              ],
              onChanged: (v) => setState(() => _method = v ?? 'ANY'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pattern,
              decoration: const InputDecoration(
                labelText: 'Pattern (glob, * allowed)',
                hintText: '/v1/feed or *.cdn.img/*',
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<RuleKind>(
              segments: const [
                ButtonSegment(value: RuleKind.slow, label: Text('Delay')),
                ButtonSegment(value: RuleKind.fail, label: Text('Fail')),
                ButtonSegment(value: RuleKind.pass, label: Text('Pass')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 12),
            if (_kind == RuleKind.slow)
              Row(
                children: [
                  const Text('Extra delay'),
                  Expanded(
                    child: Slider(
                      value: _delayMs.toDouble().clamp(0, 5000),
                      max: 5000,
                      divisions: 50,
                      label: '$_delayMs ms',
                      onChanged: (v) => setState(() => _delayMs = v.round()),
                    ),
                  ),
                  Text('$_delayMs ms', style: ThrottlerTokens.mono(size: 12)),
                ],
              ),
            if (_kind == RuleKind.fail)
              DropdownButtonFormField<FailureType>(
                initialValue: _failType,
                decoration: const InputDecoration(labelText: 'Failure'),
                items: [
                  for (final t in FailureType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) =>
                    setState(() => _failType = v ?? FailureType.http500),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.initial != null)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const RuleEditResult._delete()),
            style: TextButton.styleFrom(foregroundColor: ThrottlerTokens.red),
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
