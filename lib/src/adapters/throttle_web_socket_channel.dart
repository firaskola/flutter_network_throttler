import 'dart:async';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../engine/throttle_controller.dart';
import '../engine/throttle_engine.dart';
import '../model/failure.dart';
import '../model/request_log.dart';

/// A [WebSocketChannel] wrapper that applies a [ThrottleController]'s profile to
/// a WebSocket connection: the handshake, every inbound frame, and every
/// outbound frame — and records them in the live log alongside HTTP traffic.
///
/// The same conditions apply as for HTTP: latency and jitter delay each frame,
/// the bandwidth cap slows large frames, packet loss drops individual frames,
/// and failure injection / an offline condition fails the connection.
///
/// Wrap whatever channel you already create:
///
/// ```dart
/// import 'package:web_socket_channel/web_socket_channel.dart';
/// import 'package:flutter_network_throttler/web_socket.dart';
///
/// final raw = WebSocketChannel.connect(Uri.parse('wss://example.com/socket'));
/// final socket = ThrottleWebSocketChannel(raw, controller: controller);
///
/// socket.stream.listen(handleMessage);
/// socket.sink.add('ping');
/// ```
class ThrottleWebSocketChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  /// Wraps [inner], throttling it through [controller].
  ///
  /// [url] is used for rule matching and log display; if omitted a placeholder
  /// `ws://websocket` URI is used.
  ThrottleWebSocketChannel(this.inner, {required this.controller, Uri? url})
    : _url = url ?? Uri.parse('ws://websocket') {
    _stream = _wrapIncoming(inner.stream);
    _sink = _ThrottledWebSocketSink(inner.sink, controller.engine, _url);
  }

  /// Opens a throttled connection to [uri] in one call.
  ///
  /// Equivalent to wrapping `WebSocketChannel.connect(uri)` and using [uri] as
  /// the URL for rule matching and log display:
  ///
  /// ```dart
  /// final socket = ThrottleWebSocketChannel.connect(
  ///   Uri.parse('wss://example.com/socket'),
  ///   controller: controller,
  /// );
  /// ```
  factory ThrottleWebSocketChannel.connect(
    Uri uri, {
    required ThrottleController controller,
    Iterable<String>? protocols,
  }) {
    return ThrottleWebSocketChannel(
      WebSocketChannel.connect(uri, protocols: protocols),
      controller: controller,
      url: uri,
    );
  }

  /// The underlying channel doing the real WebSocket I/O.
  final WebSocketChannel inner;

  /// The controller whose profile drives throttling decisions.
  final ThrottleController controller;

  final Uri _url;
  late final Stream<dynamic> _stream;
  late final _ThrottledWebSocketSink _sink;

  ThrottleEngine get _engine => controller.engine;

  @override
  Stream<dynamic> get stream => _stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  Future<void> get ready => _throttledReady();

  @override
  String? get protocol => inner.protocol;

  @override
  int? get closeCode => inner.closeCode;

  @override
  String? get closeReason => inner.closeReason;

  Future<void> _throttledReady() async {
    final plan = _engine.planRequest('WS', _url);
    if (!plan.passThrough && plan.latency > Duration.zero) {
      await Future<void>.delayed(plan.latency);
    }
    if (!plan.passThrough && plan.failure != null) {
      _engine.record(
        _wsEntry(
          'WS',
          RequestOutcome.failed,
          failureMeta(plan.failure!),
          plan.latency,
        ),
      );
      throw WebSocketChannelException(
        'Simulated WebSocket connection failure (${plan.failure!.reason})',
      );
    }
    await inner.ready;
    _engine.record(
      _wsEntry(
        'WS',
        RequestOutcome.ok,
        'connected',
        plan.passThrough ? null : plan.latency,
      ),
    );
  }

  Stream<dynamic> _wrapIncoming(Stream<dynamic> source) async* {
    await for (final message in source) {
      final plan = _engine.planRequest('WS', _url);
      if (plan.passThrough) {
        _engine.record(_wsEntry('WS↓', RequestOutcome.ok, 'recv', null));
        yield message;
        continue;
      }
      if (plan.latency > Duration.zero) {
        await Future<void>.delayed(plan.latency);
      }
      if (plan.failure != null) {
        // A lost frame: drop it instead of delivering.
        _engine.record(
          _wsEntry(
            'WS↓',
            RequestOutcome.failed,
            failureMeta(plan.failure!),
            plan.latency,
          ),
        );
        continue;
      }
      final bandwidth = _engine.bandwidthDelay(byteLength(message));
      if (bandwidth > Duration.zero) {
        await Future<void>.delayed(bandwidth);
      }
      final artificial = plan.latency + bandwidth;
      final throttled = artificial > Duration.zero;
      _engine.record(
        _wsEntry(
          'WS↓',
          throttled ? RequestOutcome.throttled : RequestOutcome.ok,
          throttled ? '+${artificial.inMilliseconds}ms' : 'recv',
          throttled ? artificial : null,
        ),
      );
      yield message;
    }
  }

  RequestLogEntry _wsEntry(
    String method,
    RequestOutcome outcome,
    String meta,
    Duration? appliedDelay,
  ) {
    return RequestLogEntry(
      method: method,
      url: _url,
      outcome: outcome,
      meta: meta,
      appliedDelay: appliedDelay,
      kind: RequestKind.webSocket,
    );
  }
}

class _ThrottledWebSocketSink implements WebSocketSink {
  _ThrottledWebSocketSink(this._inner, this._engine, this._url);

  final WebSocketSink _inner;
  final ThrottleEngine _engine;
  final Uri _url;

  // Serialises throttled sends so frame order is preserved.
  Future<void> _tail = Future<void>.value();

  @override
  void add(dynamic message) {
    _tail = _tail.then((_) => _send(message));
  }

  Future<void> _send(dynamic message) async {
    final plan = _engine.planRequest('WS', _url);
    if (plan.passThrough) {
      _engine.record(_entry('WS↑', RequestOutcome.ok, 'sent', null));
      _inner.add(message);
      return;
    }
    if (plan.latency > Duration.zero) {
      await Future<void>.delayed(plan.latency);
    }
    if (plan.failure != null) {
      _engine.record(
        _entry(
          'WS↑',
          RequestOutcome.failed,
          failureMeta(plan.failure!),
          plan.latency,
        ),
      );
      return; // dropped send
    }
    final bandwidth = _engine.bandwidthDelay(byteLength(message), upload: true);
    if (bandwidth > Duration.zero) {
      await Future<void>.delayed(bandwidth);
    }
    final artificial = plan.latency + bandwidth;
    final throttled = artificial > Duration.zero;
    _engine.record(
      _entry(
        'WS↑',
        throttled ? RequestOutcome.throttled : RequestOutcome.ok,
        throttled ? '+${artificial.inMilliseconds}ms' : 'sent',
        throttled ? artificial : null,
      ),
    );
    _inner.add(message);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final message in stream) {
      add(message);
    }
    await _tail;
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    await _tail;
    return _inner.close(closeCode, closeReason);
  }

  @override
  Future<void> get done => _inner.done;

  RequestLogEntry _entry(
    String method,
    RequestOutcome outcome,
    String meta,
    Duration? appliedDelay,
  ) {
    return RequestLogEntry(
      method: method,
      url: _url,
      outcome: outcome,
      meta: meta,
      appliedDelay: appliedDelay,
      kind: RequestKind.webSocket,
    );
  }
}

/// Best-effort byte length of a WebSocket frame payload.
int byteLength(dynamic message) {
  if (message is String) return message.length;
  if (message is List<int>) return message.length;
  return 0;
}

/// The compact meta label for a failed frame/connection.
String failureMeta(EngineFailure failure) {
  if (failure.httpStatus != null) return '${failure.httpStatus}';
  return failure.type == FailureType.timeout ? 'timeout' : 'dropped';
}
