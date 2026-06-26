// Callback fields intentionally use named params rather than initializing
// formals (which can't be private + named).
// ignore_for_file: prefer_initializing_formals

/// A pluggable backing store for persisting throttler state as a JSON string.
///
/// The package stays free of any storage dependency: implement this against
/// `shared_preferences`, `hive`, a file, secure storage, or anything else, and
/// hand it to a `ThrottleController`. The controller calls [read] once on
/// startup and [write] (debounced) whenever the configuration changes.
///
/// ```dart
/// class PrefsStorage implements ThrottleStorage {
///   PrefsStorage(this._prefs);
///   final SharedPreferences _prefs;
///   @override
///   Future<String?> read() async => _prefs.getString('throttler');
///   @override
///   Future<void> write(String data) => _prefs.setString('throttler', data);
/// }
/// ```
abstract interface class ThrottleStorage {
  /// Returns the previously persisted JSON string, or `null` if none.
  Future<String?> read();

  /// Persists [data] (a JSON string).
  Future<void> write(String data);
}

/// A [ThrottleStorage] backed by two callbacks — handy for wiring an existing
/// key/value store without writing a class.
///
/// ```dart
/// ThrottleStorage storage = CallbackThrottleStorage(
///   read: () async => prefs.getString('throttler'),
///   write: (data) => prefs.setString('throttler', data),
/// );
/// ```
class CallbackThrottleStorage implements ThrottleStorage {
  /// Creates a callback-backed store.
  const CallbackThrottleStorage({
    required Future<String?> Function() read,
    required Future<void> Function(String data) write,
  }) : _read = read,
       _write = write;

  final Future<String?> Function() _read;
  final Future<void> Function(String data) _write;

  @override
  Future<String?> read() => _read();

  @override
  Future<void> write(String data) => _write(data);
}
