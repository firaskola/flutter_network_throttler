part of '../network_throttler_panel.dart';

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
