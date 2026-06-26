@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_network_throttler/web_socket.dart';
import 'package:flutter_test/flutter_test.dart';

/// Starts a local WebSocket server that echoes back `echo: <frame>` for every
/// frame it receives. Returns the bound server so the test can read its port
/// and close it afterwards.
Future<HttpServer> startEchoServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    socket.listen((data) => socket.add('echo: $data'));
  });
  return server;
}

void main() {
  group('ThrottleWebSocketChannel.connect', () {
    late HttpServer server;
    late Uri uri;

    setUp(() async {
      server = await startEchoServer();
      uri = Uri.parse('ws://127.0.0.1:${server.port}/');
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('connects, echoes a frame, and logs WS traffic', () async {
      final controller = ThrottleController(
        profile: const ThrottleProfile(enabled: false),
      );
      final socket = ThrottleWebSocketChannel.connect(
        uri,
        controller: controller,
      );
      addTearDown(() => socket.sink.close());

      await socket.ready;

      // Listen before sending so the echo isn't missed.
      final firstFrame = socket.stream.first;
      socket.sink.add('hi');
      expect(await firstFrame, 'echo: hi');

      final ws = controller.log
          .where((e) => e.kind == RequestKind.webSocket)
          .toList();
      final methods = ws.map((e) => e.method).toSet();
      expect(methods, containsAll(<String>{'WS', 'WS↑', 'WS↓'}));

      final connectEntry = ws.firstWhere((e) => e.method == 'WS');
      expect(connectEntry.meta, 'connected');
      expect(connectEntry.url, uri);
    });

    test('drops the connection when the condition is offline', () async {
      final controller = ThrottleController(
        profile: const ThrottleProfile(condition: NetworkCondition.offline),
      );
      final socket = ThrottleWebSocketChannel.connect(
        uri,
        controller: controller,
      );
      addTearDown(() => socket.sink.close());

      await expectLater(socket.ready, throwsA(isA<Exception>()));
      expect(controller.log.first.outcome, RequestOutcome.failed);
    });
  });
}
