import 'package:flutter_network_throttler/flutter_network_throttler.dart';

/// A representative, deterministic controller state used by both the screenshot
/// generator and the golden regression test, so they stay in sync.
ThrottleController buildDemoController() {
  return ThrottleController()
    ..applyPreset(NetworkCondition.threeG)
    ..addRule(
      const EndpointRule(
        method: 'GET',
        pattern: '/v1/feed',
        action: DelayAction(Duration(milliseconds: 800)),
      ),
    )
    ..addRule(
      const EndpointRule(
        method: 'POST',
        pattern: '/v1/upload',
        action: FailAction(FailureType.http500),
      ),
    )
    ..addRule(
      const EndpointRule(
        pattern: '/img/*',
        host: '*.cdn.img',
        anchored: true,
        action: PassThroughAction(),
      ),
    )
    ..toggleFailure()
    ..setFailureType(FailureType.http429)
    ..setFailureProbability(0.15)
    ..toggleTampering()
    ..setTamperMode(TamperMode.truncate)
    ..setTamperProbability(0.1)
    ..seedLog([
      RequestLogEntry(
        method: 'GET',
        url: Uri.parse('https://api.test/v1/feed?page=2'),
        outcome: RequestOutcome.throttled,
        meta: '+842ms',
        appliedDelay: const Duration(milliseconds: 842),
      ),
      RequestLogEntry(
        method: 'POST',
        url: Uri.parse('https://api.test/v1/upload'),
        outcome: RequestOutcome.failed,
        meta: '429',
      ),
      RequestLogEntry(
        method: 'GET',
        url: Uri.parse('https://api.test/v1/config'),
        outcome: RequestOutcome.ok,
        meta: 'trunc',
      ),
      RequestLogEntry(
        method: 'WS↓',
        url: Uri.parse('wss://api.test/socket'),
        outcome: RequestOutcome.ok,
        meta: 'recv',
        kind: RequestKind.webSocket,
      ),
      RequestLogEntry(
        method: 'GET',
        url: Uri.parse('https://api.test/v1/profile/me'),
        outcome: RequestOutcome.ok,
        meta: '118ms',
      ),
    ]);
}
