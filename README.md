# flutter_network_throttler

Simulate slow, unreliable, or failing network conditions in your Flutter app so
you can test loading spinners, timeouts, retries, and error states — without
depending on a real flaky server.

Route your real HTTP traffic through a throttling adapter, then tune everything
live from a drop-in debug **control panel**.

[![pub package](https://img.shields.io/pub/v/flutter_network_throttler.svg)](https://pub.dev/packages/flutter_network_throttler)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

<p align="center">
  <img src="doc/panel.png" alt="Network Throttler control panel" width="320">
</p>

## Features

- 🐢 **Conditions** — latency, jitter, bandwidth cap, and packet loss.
- 📱 **Presets** — `Offline`, `2G`, `3G`, `4G`, `WiFi`, plus **saved custom presets**.
- 💥 **Failure injection** — fail a configurable fraction of requests with a
  `timeout`, `500`, `403`, or `no-connection`.
- 🎯 **Per-endpoint rules** — glob-match a method + path and slow it, fail it, or
  let it pass through untouched — edited from a built-in rule editor.
- 📡 **Live request log** — captured with outcome, timing, metrics, filters,
  pause/clear, and tap-to-inspect.
- 🔌 **Real traffic** — a `package:http` client wrapper, a `package:dio`
  interceptor, a `WebSocketChannel` wrapper, **and** a generic `Stream`
  transformer share one engine.
- 🎛️ **Control panel** — `NetworkThrottlerPanel`, a debug UI to drive it all.
- 💾 **Persistence** — save/restore configuration via any store you plug in.
- 🎬 **Scenario scripting** — script timed conditions ("offline for 5s, then 3G").
- 🛠️ **DevTools** — drive it from Flutter DevTools via service extensions.
- 🚦 **Toggleable & deterministic** — flip `enabled` at runtime; pass a `seed`
  for repeatable tests.

## Getting started

```yaml
dependencies:
  flutter_network_throttler: ^0.0.1
```

Everything is driven by a single `ThrottleController`:

```dart
import 'package:flutter_network_throttler/flutter_network_throttler.dart';

final controller = ThrottleController();
```

## Throttle real HTTP traffic

### package:http

```dart
import 'package:http/http.dart' as http;

final client = ThrottleClient(http.Client(), controller: controller);

// Now behaves according to the controller's profile, and is logged.
final response = await client.get(Uri.parse('https://api.example.com/v1/feed'));
```

### package:dio

```dart
import 'package:dio/dio.dart';
import 'package:flutter_network_throttler/dio.dart';

final dio = Dio()..interceptors.add(ThrottleInterceptor(controller));
```

### WebSockets

Wrap a `WebSocketChannel` to throttle the handshake and every frame. The same
conditions apply: latency/jitter delay each frame, the bandwidth cap slows large
frames, packet loss drops individual frames, and failure injection (or an
offline condition) fails the connection. Frames show up in the same live log,
tagged `WS`, `WS↑` (sent), and `WS↓` (received).

```dart
import 'package:flutter_network_throttler/web_socket.dart';

// One-liner: connect and throttle in a single call.
final socket = ThrottleWebSocketChannel.connect(
  Uri.parse('wss://example.com/socket'),
  controller: controller,
);

socket.stream.listen(handleMessage);
socket.sink.add('ping');
```

Already have a channel? Wrap it instead:

```dart
import 'package:web_socket_channel/web_socket_channel.dart';

final raw = WebSocketChannel.connect(Uri.parse('wss://example.com/socket'));
final socket = ThrottleWebSocketChannel(raw, controller: controller);
```

## The control panel

`NetworkThrottlerPanel` is just the **content** (no app bar) so you can present
it however you like. Three ready-made ways:

```dart
// 1. Bottom sheet — dismiss by dragging the handle down or tapping the scrim.
showNetworkThrottlerPanel(context, controller);

// 2. Full-screen page — gets a standard back button to pop it.
showNetworkThrottlerPage(context, controller);
// (or push NetworkThrottlerPage(controller: controller) yourself)

// 3. Embedded — drop the panel into any layout (tab, drawer, split view).
Expanded(child: NetworkThrottlerPanel(controller: controller));
```

> **Pushing the bare `NetworkThrottlerPanel` as a route won't give you a back
> button** — it has no `Scaffold`/app bar by design. Use `NetworkThrottlerPage`
> (or wrap the panel in your own `Scaffold` + `AppBar`) for a page with a back
> button.

The `NetworkThrottlerButton` launcher can open either form:

```dart
NetworkThrottlerButton(
  controller: controller,
  presentation: ThrottlerPresentation.page, // default is .sheet
)
```

The panel exposes the master switch, preset chips, condition sliders, failure
injection, per-endpoint rules, and the live request log — all bound to the same
controller your client reads from.

### How users open it (debug-only)

You don't ship the panel to real users — you expose a trigger that only exists
in debug builds. `NetworkThrottlerButton` does exactly that: it renders **only
when `kDebugMode` is true** and opens the panel as a modal sheet.

**Floating button over any screen** — drop it into a `Scaffold`:

```dart
Scaffold(
  floatingActionButton: NetworkThrottlerButton(controller: controller),
  body: MyHomePage(),
)
```

**A row in your Settings screen** — pass your own trigger as `child`:

```dart
NetworkThrottlerButton(
  controller: controller,
  child: const ListTile(
    leading: Icon(Icons.network_check),
    title: Text('Network throttler'),
    subtitle: Text('Simulate slow / failing network'),
    trailing: Icon(Icons.chevron_right),
  ),
)
```

**Or wire it yourself** — gate any widget with `kDebugMode` and call the helper:

```dart
if (kDebugMode)
  IconButton(
    icon: const Icon(Icons.network_check),
    onPressed: () => showNetworkThrottlerPanel(context, controller),
  ),
```

In release builds `NetworkThrottlerButton` returns an empty widget, so there's
nothing to strip out.

### Enabling it in release builds (for testers)

Sometimes you need the throttler in a **release/profile** build — QA on a real
device, a TestFlight/internal track, reproducing a field issue. Set
`showInReleaseMode: true` to allow it.

To keep it out of *production* while still letting testers flip it on, gate that
flag behind a build-time `--dart-define`, so only builds compiled with the flag
expose it:

```dart
// Only true when the build was compiled with the flag below.
const kThrottlerEnabled = bool.fromEnvironment('ENABLE_NET_THROTTLER');

NetworkThrottlerButton(
  controller: controller,
  showInReleaseMode: kThrottlerEnabled,
)
```

Build a tester version with it on, and a normal store build with it off:

```bash
# Testers get the throttler:
flutter build apk --release --dart-define=ENABLE_NET_THROTTLER=true

# Production build — flag absent, button never renders:
flutter build apk --release
```

In debug builds the button always shows regardless of the flag, so day-to-day
development is unaffected.

## Configure in code

```dart
// Apply a preset…
controller.applyPreset(NetworkCondition.threeG);

// …or tune individual conditions.
controller
  ..setLatency(const Duration(milliseconds: 200))
  ..setPacketLoss(0.1); // 10%

// Inject failures.
controller
  ..toggleFailure()
  ..setFailureType(FailureType.http500)
  ..setFailureProbability(0.25);

// Per-endpoint rules (first match wins).
controller.addRule(const EndpointRule(
  method: 'GET',
  pattern: '/v1/feed',
  action: DelayAction(Duration(milliseconds: 800)),
));
controller.addRule(const EndpointRule(
  pattern: '*.cdn.img/*',
  action: PassThroughAction(),
));
```

## Generic streams (gRPC, SSE, event buses)

Throttle any `Stream` with `ThrottleStreamTransformer` — latency delays each
event, the bandwidth cap slows large events, packet loss drops events, and an
injected connection failure errors the stream:

```dart
final throttled = source.transform(
  ThrottleStreamTransformer<MyEvent>(
    controller,
    label: 'grpc:Updates',
    byteSizeOf: (e) => e.estimatedBytes,
  ),
);
```

## Persistence

The package depends on no storage plugin — implement `ThrottleStorage` (or use
`CallbackThrottleStorage`) against `shared_preferences`, `hive`, a file, etc.,
and the controller restores on startup and saves on every change:

```dart
final controller = ThrottleController(
  storage: CallbackThrottleStorage(
    read: () async => prefs.getString('throttler'),
    write: (data) => prefs.setString('throttler', data),
  ),
);
await controller.loaded; // optional: wait for restore before building UI
```

Every model is JSON-serialisable (`toJson` / `fromJson`) if you prefer to manage
state yourself.

## Scenario scripting

Script a timeline of conditions to reproduce flaky-network bugs or drive
integration tests deterministically:

```dart
final scenario = ThrottleScenario.offlineFor(
  const Duration(seconds: 5),
  recover: NetworkCondition.threeG,
)..start(controller);

// …or build your own steps:
ThrottleScenario([
  ScenarioStep(Duration.zero, (c) => c.applyPreset(NetworkCondition.twoG)),
  ScenarioStep(const Duration(seconds: 3),
      (c) => c.setPacketLoss(0.5)),
], loop: true).start(controller);
```

## DevTools

Drive the throttler from Flutter DevTools (or any VM-service client) without
on-screen UI — registers no-op in release builds:

```dart
registerThrottleServiceExtensions(controller);
// ext.flutter_network_throttler.enable / preset / failure / clearLog / state
```

## Without HTTP

Need to throttle an arbitrary `Future` (a repository call, a mock data source)?
Use the standalone `NetworkThrottler`:

```dart
final throttler = NetworkThrottler(condition: NetworkCondition.threeG, seed: 42);

final value = await throttler.throttle(
  () => repository.fetchProfile(),
  responseBytes: 20 * 1024,
);
```

It throws `SimulatedNetworkException` when a request is dropped.

See the [`example/`](example/) app for the panel wired to a demo client.

## Additional information

- **Issues & feature requests:** the
  [issue tracker](https://github.com/firaskola/flutter_network_throttler/issues).
- **Contributing:** see [CONTRIBUTING.md](CONTRIBUTING.md).
- **License:** [MIT](LICENSE).
