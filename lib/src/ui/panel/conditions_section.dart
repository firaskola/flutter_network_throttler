part of '../network_throttler_panel.dart';

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
            _LabeledSlider(
              label: 'Connection setup',
              color: ThrottlerTokens.indigo,
              valueText: '${c.connectionSetup.inMilliseconds} ms',
              value: c.connectionSetup.inMilliseconds.toDouble(),
              min: 0,
              max: 1000,
              divisions: 200,
              onChanged: (v) => controller.setConnectionSetup(
                Duration(milliseconds: v.round()),
              ),
            ),
            const _RowDivider(),
            _LabeledSlider(
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
            _LabeledSlider(
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
            _DistributionRow(controller: controller),
            const _RowDivider(),
            _LabeledSlider(
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
            _LabeledSlider(
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

/// Lets the user pick how jitter is distributed around the base latency.
class _DistributionRow extends StatelessWidget {
  const _DistributionRow({required this.controller});

  final ThrottleController controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.condition.distribution;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Jitter shape',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ThrottlerTokens.secondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final d in LatencyDistribution.values)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: d == LatencyDistribution.values.last ? 0 : 6,
                    ),
                    child: _MiniChip(
                      label: d.label,
                      selected: selected == d,
                      onTap: () => controller.setDistribution(d),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A compact selectable chip used by the jitter-shape selector.
class _MiniChip extends StatelessWidget {
  const _MiniChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? ThrottlerTokens.purple : ThrottlerTokens.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? ThrottlerTokens.purple
                : ThrottlerTokens.chipBorder,
          ),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : ThrottlerTokens.body,
            ),
          ),
        ),
      ),
    );
  }
}
