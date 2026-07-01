import 'package:flutter/material.dart';

import '../engine/throttle_controller.dart';
import '../model/endpoint_rule.dart';
import '../model/failure.dart';
import '../model/network_condition.dart';
import '../model/request_log.dart';
import '../model/response_tampering.dart';
import 'throttler_theme.dart';

part 'panel/shared.dart';
part 'panel/header.dart';
part 'panel/presets_section.dart';
part 'panel/conditions_section.dart';
part 'panel/failure_section.dart';
part 'panel/tampering_section.dart';
part 'panel/rules_section.dart';
part 'panel/live_log_section.dart';

/// A debug control panel for a [ThrottleController], mirroring the Network
/// Throttler design: a master switch, preset chips, condition sliders, failure
/// injection, response tampering, per-endpoint rules, and a live request log.
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
///
/// The panel is intentionally composed of small private sub-widgets (one per
/// section, under `src/ui/panel/`) so each is easy to read and maintain.
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
                        _TamperingSection(controller: controller),
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
