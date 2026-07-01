part of '../network_throttler_panel.dart';

/// Controls for response tampering: truncating, corrupting, or replacing a
/// fraction of otherwise-successful response bodies.
class _TamperingSection extends StatelessWidget {
  const _TamperingSection({required this.controller});

  final ThrottleController controller;

  @override
  Widget build(BuildContext context) {
    final tampering = controller.tampering;
    return _Section(
      title: 'Response tampering',
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
                    color: ThrottlerTokens.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.broken_image_outlined,
                    size: 16,
                    color: ThrottlerTokens.orange,
                  ),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Damage response bodies',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ThrottlerTokens.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _PillSwitch(
                  value: tampering.enabled,
                  activeColor: ThrottlerTokens.orange,
                  width: 46,
                  height: 27,
                  onChanged: (_) => controller.toggleTampering(),
                ),
              ],
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: tampering.enabled ? 1 : 0.4,
              child: IgnorePointer(
                ignoring: !tampering.enabled,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Mode',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ThrottlerTokens.secondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (final mode in TamperMode.values)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: mode == TamperMode.values.last ? 0 : 8,
                                ),
                                child: _TamperModeChip(
                                  mode: mode,
                                  selected: tampering.mode == mode,
                                  onTap: () => controller.setTamperMode(mode),
                                ),
                              ),
                            ),
                        ],
                      ),
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
                            '${(tampering.probability * 100).round()} % of responses',
                            style: ThrottlerTokens.mono(
                              color: ThrottlerTokens.orange,
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          activeTrackColor: ThrottlerTokens.orange,
                          inactiveTrackColor: ThrottlerTokens.trackInactive,
                          thumbColor: Colors.white,
                          overlayColor: ThrottlerTokens.orange.withValues(
                            alpha: 0.14,
                          ),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 9,
                          ),
                        ),
                        child: Slider(
                          value: (tampering.probability * 100).clamp(0, 100),
                          min: 0,
                          max: 100,
                          divisions: 100,
                          onChanged: (v) =>
                              controller.setTamperProbability(v / 100),
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

class _TamperModeChip extends StatelessWidget {
  const _TamperModeChip({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final TamperMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? ThrottlerTokens.orange.withValues(alpha: 0.1)
              : const Color(0xFFFAFBFC),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? ThrottlerTokens.orange : ThrottlerTokens.border,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            mode.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected
                  ? ThrottlerTokens.orange
                  : const Color(0xFF5B6270),
            ),
          ),
        ),
      ),
    );
  }
}
