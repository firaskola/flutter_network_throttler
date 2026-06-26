/// Dio adapter for `flutter_network_throttler`.
///
/// Import this entrypoint when your app uses `package:dio`:
///
/// ```dart
/// import 'package:flutter_network_throttler/flutter_network_throttler.dart';
/// import 'package:flutter_network_throttler/dio.dart';
///
/// final controller = ThrottleController();
/// final dio = Dio()..interceptors.add(ThrottleInterceptor(controller));
/// ```
library;

export 'src/adapters/throttle_dio_interceptor.dart';
