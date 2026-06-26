import 'dart:async';

import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_network_throttler/web_socket.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A minimal in-memory [WebSocketChannel] for tests: emits [_incoming] on
/// `stream` and captures sent frames in [sent].
class _FakeChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  _FakeChannel(this._incoming);

  final Stream<dynamic> _incoming;
  final List<dynamic> sent = <dynamic>[];

  @override
  Stream<dynamic> get stream => _incoming;

  @override
  WebSocketSink get sink => _FakeSink(sent);

  @override
  Future<void> get ready async {}

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;
}

class _FakeSink implements WebSocketSink {
  _FakeSink(this.sent);

  final List<dynamic> sent;

  @override
  void add(dynamic data) => sent.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) => stream.forEach(sent.add);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}

  @override
  Future<void> get done async {}
}

ThrottleWebSocketChannel wrap(
  ThrottleController controller,
  Stream<dynamic> incoming, {
  WebSocketChannel? channel,
}) {
  return ThrottleWebSocketChannel(
    channel ?? _FakeChannel(incoming),
    controller: controller,
    url: Uri.parse('wss://api.test/socket'),
  );
}

void main() {
  group('ThrottleWebSocketChannel', () {
    test('passes inbound frames through when disabled', () async {
      final controller = ThrottleController(
        profile: const ThrottleProfile(enabled: false),
      );
      final socket = wrap(controller, Stream.fromIterable(['a', 'b']));

      expect(await socket.stream.toList(), ['a', 'b']);
      final ws = controller.log
          .where((e) => e.kind == RequestKind.webSocket)
          .toList();
      expect(ws, hasLength(2));
      expect(ws.every((e) => e.outcome == RequestOutcome.ok), isTrue);
    });

    test('drops inbound frames on total packet loss', () async {
      final controller = ThrottleController(
        profile: const ThrottleProfile(
          condition: NetworkCondition(packetLoss: 1.0),
        ),
      );
      final socket = wrap(controller, Stream.fromIterable(['x']));

      expect(await socket.stream.toList(), isEmpty);
      expect(controller.log.first.outcome, RequestOutcome.failed);
      expect(controller.log.first.method, 'WS↓');
    });

    test('logs outbound frames and forwards them', () async {
      final controller = ThrottleController(
        profile: const ThrottleProfile(enabled: false),
      );
      final channel = _FakeChannel(const Stream.empty());
      final socket = wrap(controller, const Stream.empty(), channel: channel);

      socket.sink.add('hello');
      await socket.sink.close();

      expect(channel.sent, ['hello']);
      expect(controller.log.first.method, 'WS↑');
      expect(controller.log.first.kind, RequestKind.webSocket);
    });

    test('ready throws when a connection failure is injected', () async {
      final controller = ThrottleController(
        profile: const ThrottleProfile(
          condition: NetworkCondition.perfect,
          failure: FailureInjection(
            enabled: true,
            type: FailureType.noConnection,
            probability: 1.0,
          ),
        ),
      );
      final socket = wrap(controller, const Stream.empty());

      await expectLater(
        socket.ready,
        throwsA(isA<WebSocketChannelException>()),
      );
      expect(controller.log.first.outcome, RequestOutcome.failed);
    });

    test('ready resolves and logs a connection when healthy', () async {
      final controller = ThrottleController(
        profile: const ThrottleProfile(condition: NetworkCondition.perfect),
      );
      final socket = wrap(controller, const Stream.empty());

      await socket.ready;
      expect(controller.log.first.method, 'WS');
      expect(controller.log.first.meta, 'connected');
    });
  });
}
