/// Build-time configuration. Pass with `--dart-define` or `--dart-define-from-file`.
///
/// `10.0.2.2` reaches the host machine from the Android emulator.
abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:4000',
  );
  static const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0');

  /// Product name, the same on the web dashboard. Also set in AndroidManifest.xml and Info.plist.
  static const appName = 'Attendly';
  static const tagline = 'Attendance made simple';

  /// Minutes in background before the app re-locks.
  static const relockAfterMinutes = 5;
}
