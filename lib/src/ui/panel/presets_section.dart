part of '../network_throttler_panel.dart';

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
