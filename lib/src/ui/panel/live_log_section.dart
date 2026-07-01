part of '../network_throttler_panel.dart';

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
