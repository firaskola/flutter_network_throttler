import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../engine/throttle_controller.dart';
import 'network_throttler_panel.dart';
import 'throttler_theme.dart';

/// How [NetworkThrottlerButton] presents the panel.
enum ThrottlerPresentation {
  /// A modal bottom sheet (dismiss by dragging down or tapping the scrim).
  sheet,

  /// A full-screen page with a back button.
  page,
}

/// A launcher that opens the [NetworkThrottlerPanel] as a modal sheet, and —
/// crucially — only renders in debug builds, so it never ships to your users.
///
/// By default it is a small floating action button you can drop into any
/// `Scaffold`:
///
/// ```dart
/// Scaffold(
///   floatingActionButton: NetworkThrottlerButton(controller: controller),
///   body: ...,
/// )
/// ```
///
/// Provide a [child] to use your own trigger (e.g. an `AppBar` action or a
/// settings row); tapping it opens the panel:
///
/// ```dart
/// NetworkThrottlerButton(
///   controller: controller,
///   child: const ListTile(
///     leading: Icon(Icons.network_check),
///     title: Text('Network throttler'),
///     trailing: Icon(Icons.chevron_right),
///   ),
/// )
/// ```
///
/// In release builds this returns an empty widget. To make it available to
/// testers in a release/profile build, set [showInReleaseMode] — ideally behind
/// a build-time flag so it never reaches production:
///
/// ```dart
/// NetworkThrottlerButton(
///   controller: controller,
///   showInReleaseMode: const bool.fromEnvironment('ENABLE_NET_THROTTLER'),
/// )
/// ```
///
/// Then build a tester version with
/// `flutter build --release --dart-define=ENABLE_NET_THROTTLER=true`, while a
/// plain release build leaves the flag off and the button never renders. Debug
/// builds always show it regardless.
class NetworkThrottlerButton extends StatelessWidget {
  /// Creates a debug launcher for [controller].
  const NetworkThrottlerButton({
    super.key,
    required this.controller,
    this.child,
    this.showInReleaseMode = false,
    this.presentation = ThrottlerPresentation.sheet,
    this.tooltip = 'Network Throttler',
  });

  /// The controller the opened panel binds to.
  final ThrottleController controller;

  /// An optional custom trigger. When `null`, a small FAB is shown.
  final Widget? child;

  /// Whether to also show the launcher in release builds. Defaults to `false`.
  final bool showInReleaseMode;

  /// Whether tapping opens a bottom sheet (default) or a full-screen page.
  final ThrottlerPresentation presentation;

  /// Tooltip for the default FAB.
  final String tooltip;

  bool get _visible => showInReleaseMode || kDebugMode;

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    void open() => switch (presentation) {
      ThrottlerPresentation.sheet => showNetworkThrottlerPanel(
        context,
        controller,
      ),
      ThrottlerPresentation.page => showNetworkThrottlerPage(
        context,
        controller,
      ),
    };

    final trigger = child;
    if (trigger != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: trigger,
      );
    }

    return FloatingActionButton.small(
      heroTag: 'network_throttler_button',
      tooltip: tooltip,
      backgroundColor: ThrottlerTokens.ink,
      foregroundColor: Colors.white,
      onPressed: open,
      child: const Icon(Icons.network_check_rounded),
    );
  }
}
