part of '../network_throttler_panel.dart';

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rule.pattern,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ThrottlerTokens.mono(
                      size: 12,
                      weight: FontWeight.w500,
                      color: ThrottlerTokens.ink,
                    ),
                  ),
                  if (_constraintSummary(rule) case final summary?)
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: ThrottlerTokens.label,
                      ),
                    ),
                ],
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

  /// A compact description of any extra match constraints on the rule.
  static String? _constraintSummary(EndpointRule rule) {
    final parts = <String>[
      if (rule.anchored) 'anchored',
      if (rule.host != null) 'host ${rule.host}',
      for (final e in rule.query.entries) '?${e.key}=${e.value}',
      for (final e in rule.headers.entries) '${e.key}: ${e.value}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

// --- rule editor -----------------------------------------------------------

/// The result of editing a rule: either a [rule] to save, or a delete request.
class RuleEditResult extends EndpointRule {
  const RuleEditResult._delete()
    : isDelete = true,
      super(pattern: '', action: const PassThroughAction());

  /// Wraps [rule] as a save result.
  RuleEditResult.save(EndpointRule rule)
    : isDelete = false,
      super(
        method: rule.method,
        pattern: rule.pattern,
        action: rule.action,
        host: rule.host,
        query: rule.query,
        headers: rule.headers,
        anchored: rule.anchored,
      );

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
  late TextEditingController _host;
  late TextEditingController _query;
  late TextEditingController _headers;
  late bool _anchored;
  late RuleKind _kind;
  late int _delayMs;
  late FailureType _failType;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _method = r?.method ?? 'ANY';
    _pattern = TextEditingController(text: r?.pattern ?? '/v1/');
    _host = TextEditingController(text: r?.host ?? '');
    _query = TextEditingController(text: _formatPairs(r?.query));
    _headers = TextEditingController(text: _formatPairs(r?.headers));
    _anchored = r?.anchored ?? false;
    final action = r?.action;
    _kind = action?.kind ?? RuleKind.slow;
    _delayMs = action is DelayAction ? action.extra.inMilliseconds : 500;
    _failType = action is FailAction ? action.type : FailureType.http500;
  }

  @override
  void dispose() {
    _pattern.dispose();
    _host.dispose();
    _query.dispose();
    _headers.dispose();
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
    final host = _host.text.trim();
    final rule = EndpointRule(
      method: _method == 'ANY' ? null : _method,
      pattern: _pattern.text.trim(),
      action: _buildAction(),
      host: host.isEmpty ? null : host,
      query: _parsePairs(_query.text),
      headers: _parsePairs(_headers.text),
      anchored: _anchored,
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Match whole URL (anchored)'),
              subtitle: const Text('Off = substring match'),
              value: _anchored,
              onChanged: (v) => setState(() => _anchored = v),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _host,
              decoration: const InputDecoration(
                labelText: 'Host (optional glob)',
                hintText: 'api.example.com or *.cdn.example.com',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _query,
              decoration: const InputDecoration(
                labelText: 'Query match (optional)',
                hintText: 'page=*, sort=desc',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _headers,
              decoration: const InputDecoration(
                labelText: 'Header match (optional)',
                hintText: 'authorization=Bearer *',
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

/// Parses a `k=v, k2=v2` string into a map; ignores blank/`=`-less entries.
Map<String, String> _parsePairs(String text) {
  final out = <String, String>{};
  for (final part in text.split(',')) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) continue;
    final eq = trimmed.indexOf('=');
    if (eq <= 0) continue;
    out[trimmed.substring(0, eq).trim()] = trimmed.substring(eq + 1).trim();
  }
  return out;
}

String _formatPairs(Map<String, String>? map) {
  if (map == null || map.isEmpty) return '';
  return map.entries.map((e) => '${e.key}=${e.value}').join(', ');
}
