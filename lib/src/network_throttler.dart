import 'dart:async';
import 'dart:math';

import 'model/network_condition.dart';
import 'model/network_exception.dart';

/// Applies a [NetworkCondition] to asynchronous operations, simulating the
/// latency, bandwidth limits, and failures of a real-world connection.
///
/// Wrap any future-returning work — an HTTP call, a repository method, a mock
/// data source — with [throttle] to make it behave as if it ran over the
/// configured network:
///
/// ```dart
/// final throttler = NetworkThrottler(condition: NetworkCondition.threeG);
///
/// final response = await throttler.throttle(
///   () => httpClient.get(uri),
///   responseBytes: 50 * 1024, // 50 KB payload, used for bandwidth delay
/// );
/// ```
///
/// The throttler can be toggled at runtime with [enabled], so the same code
/// path can run unthrottled in production and throttled in debug or test
/// builds.
class NetworkThrottler {
  /// Creates a throttler for the given [condition].
  ///
  /// Pass a [seed] to make latency jitter and failures deterministic, which is
  /// useful in automated tests.
  NetworkThrottler({
    this.condition = NetworkCondition.perfect,
    this.enabled = true,
    int? seed,
  }) : _random = Random(seed);

  /// Whether throttling is currently applied.
  ///
  /// When `false`, [throttle] runs the operation immediately with no added
  /// delay or simulated failures.
  bool enabled;

  /// The network condition currently being simulated.
  ///
  /// May be reassigned at runtime; the new value takes effect on the next
  /// [throttle] call.
  NetworkCondition condition;

  final Random _random;

  /// Runs [operation] under the active [condition].
  ///
  /// The returned future completes with the operation's value after the
  /// simulated latency and transfer time have elapsed. It may instead throw a
  /// [SimulatedNetworkException] according to the condition's packet loss.
  ///
  /// * [requestBytes] — size of the outbound payload, delayed by the upload
  ///   bandwidth.
  /// * [responseBytes] — size of the inbound payload, delayed by the download
  ///   bandwidth.
  ///
  /// When [enabled] is `false`, [operation] is awaited directly with no
  /// modifications.
  Future<T> throttle<T>(
    Future<T> Function() operation, {
    int requestBytes = 0,
    int responseBytes = 0,
  }) async {
    if (!enabled) {
      return operation();
    }

    // Capture once so a mid-call reassignment can't change behaviour partway.
    final condition = this.condition;

    // Apply latency (plus jitter) before doing anything else.
    await Future<void>.delayed(_nextLatency(condition));

    // Possibly fail outright before the operation runs.
    if (_shouldFail(condition)) {
      throw SimulatedNetworkException(
        condition.isOffline
            ? 'Network is offline'
            : 'Simulated network failure',
        condition: condition,
      );
    }

    // Simulate time spent uploading the request body.
    await Future<void>.delayed(
      transferDuration(requestBytes, condition.uploadKbps),
    );

    final result = await operation();

    // Simulate time spent downloading the response body.
    await Future<void>.delayed(
      transferDuration(responseBytes, condition.downloadKbps),
    );

    return result;
  }

  /// Computes how long transferring [bytes] takes at [kbps] kilobits/second.
  ///
  /// Returns [Duration.zero] when [kbps] is `0` (treated as unlimited) or when
  /// there are no [bytes] to transfer. Exposed for testing and instrumentation.
  static Duration transferDuration(int bytes, int kbps) {
    if (kbps <= 0 || bytes <= 0) {
      return Duration.zero;
    }
    final bits = bytes * 8;
    final seconds = bits / (kbps * 1000);
    return Duration(
      microseconds: (seconds * Duration.microsecondsPerSecond).round(),
    );
  }

  Duration _nextLatency(NetworkCondition condition) {
    final jitterMicros = condition.latencyJitter.inMicroseconds;
    final extra = jitterMicros <= 0 ? 0 : _random.nextInt(jitterMicros + 1);
    return condition.latency + Duration(microseconds: extra);
  }

  bool _shouldFail(NetworkCondition condition) {
    if (condition.packetLoss <= 0.0) {
      return false;
    }
    if (condition.packetLoss >= 1.0) {
      return true;
    }
    return _random.nextDouble() < condition.packetLoss;
  }
}
