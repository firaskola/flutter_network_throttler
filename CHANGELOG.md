## 1.0.0

Initial release.

### Models
* `NetworkCondition` describing latency, jitter, bandwidth, and **packet loss**,
  with presets `perfect`, `wifi`, `fourG`, `threeG`, `twoG`, and `offline`.
* `FailureInjection` + `FailureType` (timeout / 500 / 403 / no-connection) for
  injecting specific failures into otherwise-healthy requests.
* `EndpointRule` with glob matching and `DelayAction` / `FailAction` /
  `PassThroughAction` for per-endpoint overrides.
* `RequestLogEntry` / `ThrottleProfile` for captured traffic and the full config.

* JSON serialisation (`toJson` / `fromJson`) on every model.

### Engine
* `ThrottleEngine` — adapter-agnostic decision core (latency, packet loss,
  failure injection, rule precedence, bandwidth math).
* `ThrottleController` — a `ChangeNotifier` source of truth with a capped live
  request log; the thing the UI binds to and the adapters read. Includes saved
  custom presets, capture pause, `ThrottleMetrics`, and optional persistence.

### Adapters
* `ThrottleClient` — a drop-in `package:http` `BaseClient` wrapper.
* `ThrottleInterceptor` — a `package:dio` interceptor, via
  `package:flutter_network_throttler/dio.dart`.
* `ThrottleWebSocketChannel` — a `WebSocketChannel` wrapper that throttles the
  handshake and individual frames, via
  `package:flutter_network_throttler/web_socket.dart`. Frames are tagged
  `WS` / `WS↑` / `WS↓` in the live log. Use `ThrottleWebSocketChannel.connect()`
  to open and throttle a connection in one call.
* `ThrottleStreamTransformer` — throttle any `Stream` (gRPC, SSE, event buses).

### Persistence, scenarios, DevTools
* `ThrottleStorage` / `CallbackThrottleStorage` — plug in any backing store;
  the controller restores on startup and saves on change.
* `ThrottleScenario` — script timed conditions, with an `offlineFor` helper and
  optional looping.
* `registerThrottleServiceExtensions` — drive the controller from Flutter
  DevTools; no-ops in release.

### UI
* `NetworkThrottlerPanel` debug control panel matching the design. Present it as
  a bottom sheet (`showNetworkThrottlerPanel`, now with a drag handle), a
  full-screen page with a back button (`NetworkThrottlerPage` /
  `showNetworkThrottlerPage`), or embedded directly.
* `NetworkThrottlerButton` — a `kDebugMode`-gated launcher (FAB or custom
  trigger) that opens the panel and disappears in release builds.
* Live-log metrics strip, HTTP/WS/failed filters, pause & clear, and
  tap-to-inspect; an in-panel rule editor; "Save current" custom presets.

### Core
* `NetworkThrottler.throttle()` generic `Future` wrapper and
  `SimulatedNetworkException`, with deterministic behaviour via an optional
  random `seed`.
