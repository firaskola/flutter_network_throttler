/// Simulate slow, unreliable, or failing network conditions in Flutter apps.
///
/// Wrap your asynchronous network calls with a [NetworkThrottler] — or route
/// real HTTP traffic through `ThrottleClient` (package:http) / the dio adapter
/// in `package:flutter_network_throttler/dio.dart` — to test how your UI
/// behaves under realistic conditions: loading spinners, timeouts, retries, and
/// error states, without depending on a real flaky server.
///
/// Drop the [NetworkThrottlerPanel] into a debug build to tune conditions,
/// inject failures, define per-endpoint rules, and watch a live request log.
library;

// Models
export 'src/model/endpoint_rule.dart';
export 'src/model/failure.dart';
export 'src/model/network_condition.dart';
export 'src/model/network_exception.dart';
export 'src/model/request_log.dart';
export 'src/model/response_tampering.dart';
export 'src/model/throttle_profile.dart';

// Engine + controller
export 'src/engine/throttle_controller.dart';
export 'src/engine/throttle_engine.dart';

// Persistence
export 'src/persistence/throttle_storage.dart';

// Scenario scripting
export 'src/scenario/throttle_scenario.dart';

// DevTools / VM-service integration
export 'src/devtools/service_extensions.dart';

// HTTP adapter (package:http). The dio adapter lives in
// `package:flutter_network_throttler/dio.dart`; the WebSocket adapter in
// `package:flutter_network_throttler/web_socket.dart`.
export 'src/adapters/throttle_http_client.dart';
export 'src/adapters/throttle_stream_transformer.dart';

// Core throttler (generic Future wrapper)
export 'src/network_throttler.dart';

// UI control panel + debug launcher
export 'src/ui/network_throttler_button.dart';
export 'src/ui/network_throttler_panel.dart';
export 'src/ui/network_throttler_scope.dart';
