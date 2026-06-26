import 'network_condition.dart';

/// Thrown when a simulated connection-level failure occurs (packet loss, an
/// offline network, or a `throttle()` call that rolls a drop).
///
/// This lets you exercise the error-handling paths of your app without a real
/// flaky server. Catch it just as you would a real network error.
class SimulatedNetworkException implements Exception {
  /// Creates a simulated network exception.
  const SimulatedNetworkException(this.message, {this.condition});

  /// A description of why the simulated request failed.
  final String message;

  /// The [NetworkCondition] that produced this failure, if available.
  final NetworkCondition? condition;

  @override
  String toString() {
    final conditionName = condition?.name;
    if (conditionName == null) {
      return 'SimulatedNetworkException: $message';
    }
    return 'SimulatedNetworkException ($conditionName): $message';
  }
}
