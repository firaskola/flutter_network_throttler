import 'dart:async';

import '../engine/throttle_controller.dart';
import '../model/request_log.dart';

/// A [StreamTransformer] that applies a [ThrottleController]'s profile to an
/// arbitrary stream of events — gRPC streaming responses, SSE, a domain event
/// bus, anything.
///
/// Each event is treated like an inbound frame: latency/jitter delay it, the
/// bandwidth cap slows it by [byteSizeOf], packet loss drops it, and failure
/// injection / an offline condition turns it into a stream error. Events are
/// recorded in the live log with the [label] you provide.
///
/// ```dart
/// final throttled = sourceStream.transform(
///   ThrottleStreamTransformer<MyEvent>(
///     controller,
///     label: 'grpc:Updates',
///     byteSizeOf: (e) => e.writeToBuffer().length,
///   ),
/// );
/// ```
class ThrottleStreamTransformer<T> extends StreamTransformerBase<T, T> {
  /// Creates a transformer driven by [controller].
  ///
  /// [label] is shown in the live log (and used for rule matching, as the path
  /// of a `stream://` URL). [byteSizeOf] estimates an event's payload size for
  /// the bandwidth cap; when omitted, bandwidth throttling is skipped.
  ThrottleStreamTransformer(
    this.controller, {
    this.label = 'stream',
    this.byteSizeOf,
  });

  /// The controller whose profile drives throttling decisions.
  final ThrottleController controller;

  /// A short label identifying this stream in the log.
  final String label;

  /// Estimates the byte size of an event for bandwidth throttling.
  final int Function(T event)? byteSizeOf;

  Uri get _url => Uri.parse('stream://$label');

  @override
  Stream<T> bind(Stream<T> stream) async* {
    final engine = controller.engine;
    await for (final event in stream) {
      final plan = engine.planRequest('STREAM', _url);
      if (plan.passThrough) {
        engine.record(_entry(RequestOutcome.ok, 'event'));
        yield event;
        continue;
      }
      if (plan.latency > Duration.zero) {
        await Future<void>.delayed(plan.latency);
      }
      final failure = plan.failure;
      if (failure != null) {
        engine.record(
          _entry(
            RequestOutcome.failed,
            failure.httpStatus?.toString() ?? failure.type.code.toLowerCase(),
          ),
        );
        // Packet loss drops a single frame (the stream stays open and just goes
        // quiet); an injected connection failure breaks the whole stream.
        if (failure.isConnectionLevel && failure.reason != 'packet loss') {
          throw StateError('Simulated stream failure (${failure.reason})');
        }
        continue;
      }
      final bytes = byteSizeOf?.call(event) ?? 0;
      final bandwidth = engine.bandwidthDelay(bytes);
      if (bandwidth > Duration.zero) {
        await Future<void>.delayed(bandwidth);
      }
      final artificial = plan.latency + bandwidth;
      final throttled = artificial > Duration.zero;
      engine.record(
        _entry(
          throttled ? RequestOutcome.throttled : RequestOutcome.ok,
          throttled ? '+${artificial.inMilliseconds}ms' : 'event',
        ),
      );
      yield event;
    }
  }

  RequestLogEntry _entry(RequestOutcome outcome, String meta) =>
      RequestLogEntry(method: 'STRM', url: _url, outcome: outcome, meta: meta);
}
