part of '../network_throttler_panel.dart';

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
                      if (failure.type == FailureType.http429) ...[
                        const SizedBox(height: 16),
                        _RetryAfterRow(controller: controller),
                      ],
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

/// The `Retry-After` control, shown only when the 429 failure type is selected.
class _RetryAfterRow extends StatelessWidget {
  const _RetryAfterRow({required this.controller});

  final ThrottleController controller;

  @override
  Widget build(BuildContext context) {
    final seconds = controller.failure.retryAfter.inSeconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Retry-After',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ThrottlerTokens.ink,
              ),
            ),
            const Spacer(),
            Text(
              '$seconds s',
              style: ThrottlerTokens.mono(color: ThrottlerTokens.amber),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: ThrottlerTokens.amber,
            inactiveTrackColor: ThrottlerTokens.trackInactive,
            thumbColor: Colors.white,
            overlayColor: ThrottlerTokens.amber.withValues(alpha: 0.14),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
          ),
          child: Slider(
            value: seconds.toDouble().clamp(0, 120),
            max: 120,
            divisions: 120,
            onChanged: (v) =>
                controller.setRetryAfter(Duration(seconds: v.round())),
          ),
        ),
      ],
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
