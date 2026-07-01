## 1.1.0

A feature + reach release. **No breaking changes** — every new field defaults to
the previous behaviour.

### Wider compatibility
* **Lowered the SDK floor** from `sdk: ^3.12.2` to `sdk: ^3.8.0`
  (`flutter: ">=3.32.0"`), so the package resolves for the whole modern Dart 3
  ecosystem instead of only the newest toolchain. (3.8 is the true minimum — the
  panel uses null-aware elements, wildcard parameters, and
  `DropdownButtonFormField.initialValue`, all introduced after Dart 3.0.)

### New simulation features
* **Connection-setup delay** — `NetworkCondition.connectionSetup` models the
  one-off DNS + TLS + connect cost, applied before per-request latency. The
  mobile presets now include realistic values.
* **Latency distributions** — `LatencyDistribution.uniform` / `gaussian` /
  `longTail` shape the jitter draw; `3G`/`2G` default to long-tail.
* **429 / Retry-After** — new `FailureType.http429` synthesizes a 429 carrying a
  `Retry-After` header (configurable via `FailureInjection.retryAfter`) for
  rate-limit/back-off testing.
* **Response tampering** — `ResponseTampering` (truncate / corrupt bytes /
  garbage body) damages a fraction of successful responses to test parser
  robustness.
* **Richer endpoint rules** — `EndpointRule` gains `host`, `query`, and `headers`
  matchers and an `anchored` flag (substring matching is still the default).

### HTTP adapter
* **Streaming responses** — `ThrottleClient` now streams the response body
  through with the bandwidth cap applied **progressively per chunk** instead of
  buffering the whole payload in memory. Opt back into buffering with
  `ThrottleClient(..., streamResponses: false)`.

### UI
* Panel decomposed into per-section sub-widgets under `src/ui/panel/` for
  maintainability (public API unchanged).
* New controls: connection-setup slider, jitter-shape selector, Retry-After
  slider (429), and a Response-tampering section.
* `NetworkThrottlerScope` — a framework-agnostic `InheritedNotifier` for
  providing the controller to a subtree (works alongside provider / Riverpod /
  Bloc, no extra dependency).

### Testing
* Real **golden assertions** (`matchesGoldenFile`) for the panel, with a
  tolerant comparator so they run on any platform.
* The screenshot generator now loads **checked-in Roboto fonts**, so it runs
  everywhere instead of skipping off macOS.
* Added concurrency, streaming, tampering, 429, distribution, and rule-matching
  tests.

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
