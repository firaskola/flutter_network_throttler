import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_network_throttler/web_socket.dart';
import 'package:http/http.dart' as http;
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Network Throttler Example',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const HomePage(),
    );
  }
}

/// A stand-in backend so the demo needs no real server: it returns a small
/// JSON body for every request after a tiny "server" delay. The throttler wraps
/// this client, so latency/failures/rules are layered on top.
class _DemoBackend extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final body = utf8.encode('{"ok":true,"path":"${request.url.path}"}');
    return http.StreamedResponse(
      Stream<List<int>>.value(body),
      200,
      contentLength: body.length,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

/// An in-memory WebSocket that echoes every frame it is sent, so the demo can
/// show WebSocket frames flowing through the throttler with no real server.
class _EchoChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  final StreamController<dynamic> _out = StreamController<dynamic>.broadcast();

  @override
  Stream<dynamic> get stream => _out.stream;

  @override
  WebSocketSink get sink => _EchoSink(_out);

  @override
  Future<void> get ready async {}

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;
}

class _EchoSink implements WebSocketSink {
  _EchoSink(this._out);

  final StreamController<dynamic> _out;

  @override
  void add(dynamic data) => _out.add('echo: $data');

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) => stream.forEach(add);

  @override
  Future<void> close([int? closeCode, String? closeReason]) => _out.close();

  @override
  Future<void> get done => _out.done;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // The single source of truth the panel edits and the clients read.
  final ThrottleController _controller = ThrottleController(
    profile: ThrottleProfile.initial.copyWith(
      rules: const [
        EndpointRule(
          method: 'GET',
          pattern: '/v1/feed',
          action: DelayAction(Duration(milliseconds: 800)),
        ),
        EndpointRule(
          method: 'POST',
          pattern: '/v1/upload',
          action: FailAction(FailureType.http429),
        ),
        // Match by host: let CDN images bypass throttling entirely.
        EndpointRule(
          pattern: '/*',
          host: '*.cdn.img',
          action: PassThroughAction(),
        ),
      ],
    ),
  );

  // An "offline blip" scenario: go offline for 4s, then recover to 3G.
  final ThrottleScenario _scenario = ThrottleScenario.offlineFor(
    const Duration(seconds: 4),
  );

  late final http.Client _client = ThrottleClient(
    _DemoBackend(),
    controller: _controller,
  );

  late final ThrottleWebSocketChannel _socket = ThrottleWebSocketChannel(
    _EchoChannel(),
    controller: _controller,
    url: Uri.parse('wss://demo.example.com/socket'),
  );

  static const _samples = <(String method, String url)>[
    ('GET', 'https://api.example.com/v1/feed?page=2'),
    ('POST', 'https://api.example.com/v1/upload'),
    ('GET', 'https://api.example.com/v1/profile/me'),
    ('GET', 'https://assets.cdn.img/hero.webp'),
  ];

  int _next = 0;
  int _wsSeq = 0;

  @override
  void initState() {
    super.initState();
    // Keep the socket open so echoed frames flow through the throttler.
    _socket.stream.listen((_) {});
    // Optional: drive the throttler from Flutter DevTools too (no-ops in
    // release builds).
    registerThrottleServiceExtensions(_controller);
  }

  Future<void> _sendHttp() async {
    final (method, url) = _samples[_next++ % _samples.length];
    final uri = Uri.parse(url);
    try {
      if (method == 'POST') {
        await _client.post(uri, body: 'payload');
      } else {
        await _client.get(uri);
      }
    } catch (_) {
      // Simulated failures surface as exceptions — the live log shows them.
    }
  }

  // Fire ten requests at once to watch concurrent throttling in the live log.
  Future<void> _burst() async {
    await Future.wait([for (var i = 0; i < 10; i++) _sendHttp()]);
  }

  // Play the offline → 3G scenario against the controller.
  void _runScenario() => _scenario.start(_controller);

  void _sendWs() => _socket.sink.add('ping ${_wsSeq++}');

  @override
  void dispose() {
    _scenario.stop();
    _client.close();
    _socket.sink.close();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This demo embeds the panel full-screen so you can watch the live log.
    // In a real app you'd instead expose it behind a debug-only trigger, e.g.
    // `NetworkThrottlerButton(controller: _controller)` as a FAB, or a Settings
    // row — both vanish in release builds. See the README for those patterns.
    return Scaffold(
      body: SafeArea(child: NetworkThrottlerPanel(controller: _controller)),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'scenario',
            tooltip: 'Offline blip → 3G',
            onPressed: _runScenario,
            child: const Icon(Icons.timeline_rounded),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'burst',
            tooltip: 'Fire 10 concurrent requests',
            onPressed: _burst,
            child: const Icon(Icons.dynamic_feed_rounded),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'ws',
            onPressed: _sendWs,
            icon: const Icon(Icons.bolt_rounded),
            label: const Text('WS frame'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'http',
            onPressed: _sendHttp,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Send request'),
          ),
        ],
      ),
    );
  }
}
