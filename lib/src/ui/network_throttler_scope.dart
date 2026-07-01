import 'package:flutter/widgets.dart';

import '../engine/throttle_controller.dart';

/// Provides a [ThrottleController] to a widget subtree, the framework-agnostic
/// way — no `provider`, `flutter_riverpod`, or `flutter_bloc` dependency needed.
///
/// Because [ThrottleController] is a [ChangeNotifier], descendants that read it
/// via [NetworkThrottlerScope.of] rebuild when the configuration changes (it is
/// an [InheritedNotifier]).
///
/// ```dart
/// NetworkThrottlerScope(
///   controller: controller,
///   child: MyApp(),
/// );
///
/// // Anywhere below:
/// final controller = NetworkThrottlerScope.of(context);
/// ```
///
/// Already using a DI/state-management package? [ThrottleController] drops
/// straight in:
/// * **provider** — `ChangeNotifierProvider.value(value: controller)`.
/// * **Riverpod** — expose it from a `ChangeNotifierProvider` / `Provider`.
/// * **Bloc** — hold it in a cubit, or just `RepositoryProvider.value`.
class NetworkThrottlerScope extends InheritedNotifier<ThrottleController> {
  /// Creates a scope exposing [controller] to [child].
  const NetworkThrottlerScope({
    super.key,
    required ThrottleController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The controller provided to the subtree.
  ThrottleController get controller => notifier!;

  /// The nearest controller above [context]. Throws if there is none.
  static ThrottleController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<NetworkThrottlerScope>();
    assert(scope != null, 'No NetworkThrottlerScope found in the widget tree.');
    return scope!.notifier!;
  }

  /// The nearest controller above [context], or `null` if there is none.
  static ThrottleController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<NetworkThrottlerScope>()
      ?.notifier;
}
