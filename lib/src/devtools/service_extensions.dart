import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../engine/throttle_controller.dart';
import '../model/network_condition.dart';

/// Registers `dart:developer` service extensions so the [controller] can be
/// driven from Flutter DevTools (or any VM-service client) without on-screen UI.
///
/// Registered methods (all under the `ext.flutter_network_throttler.` prefix):
///
/// | Method        | Params                | Effect                          |
/// |---------------|-----------------------|---------------------------------|
/// | `enable`      | `value=true|false`    | Master switch                   |
/// | `preset`      | `name=2G|3G|4G|WiFi|Offline` | Apply a built-in preset  |
/// | `failure`     | `enabled`, `type`, `probability` | Configure injection  |
/// | `clearLog`    | —                     | Clear the live log              |
/// | `state`       | —                     | Returns the current JSON state  |
///
/// No-ops in release builds (and is safe to call when no VM service is present).
/// Returns the number of extensions registered.
int registerThrottleServiceExtensions(ThrottleController controller) {
  if (kReleaseMode) return 0;

  const prefix = 'ext.flutter_network_throttler.';
  var count = 0;

  void register(
    String name,
    FutureOr<developer.ServiceExtensionResponse> Function(
      Map<String, String> params,
    )
    handler,
  ) {
    developer.registerExtension(prefix + name, (method, params) async {
      try {
        return await handler(params);
      } catch (error) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          '$error',
        );
      }
    });
    count++;
  }

  developer.ServiceExtensionResponse ok([Map<String, dynamic>? extra]) {
    return developer.ServiceExtensionResponse.result(
      jsonEncode({'success': true, ...?extra}),
    );
  }

  register('enable', (params) {
    controller.setEnabled(params['value'] != 'false');
    return ok({'enabled': controller.enabled});
  });

  register('preset', (params) {
    final name = params['name'];
    final preset = NetworkCondition.presets
        .where((c) => c.name.toLowerCase() == name?.toLowerCase())
        .firstOrNull;
    if (preset == null) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        'Unknown preset: $name',
      );
    }
    controller.applyPreset(preset);
    return ok({'preset': preset.name});
  });

  register('failure', (params) {
    final wantEnabled = params['enabled'];
    if (wantEnabled != null &&
        (wantEnabled == 'true') != controller.failure.enabled) {
      controller.toggleFailure();
    }
    final probability = double.tryParse(params['probability'] ?? '');
    if (probability != null) {
      controller.setFailureProbability(probability.clamp(0, 1));
    }
    return ok({'failure': controller.failure.toJson()});
  });

  register('clearLog', (_) {
    controller.clearLog();
    return ok();
  });

  register('state', (_) {
    return developer.ServiceExtensionResponse.result(controller.encodeState());
  });

  return count;
}
