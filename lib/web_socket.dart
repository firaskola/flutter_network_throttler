/// WebSocket adapter for `flutter_network_throttler`.
///
/// Import this entrypoint when you want to throttle a WebSocket connection:
///
/// ```dart
/// import 'package:flutter_network_throttler/flutter_network_throttler.dart';
/// import 'package:flutter_network_throttler/web_socket.dart';
/// import 'package:web_socket_channel/web_socket_channel.dart';
///
/// final raw = WebSocketChannel.connect(Uri.parse('wss://example.com/socket'));
/// final socket = ThrottleWebSocketChannel(raw, controller: controller);
/// ```
library;

export 'src/adapters/throttle_web_socket_channel.dart'
    show ThrottleWebSocketChannel;
