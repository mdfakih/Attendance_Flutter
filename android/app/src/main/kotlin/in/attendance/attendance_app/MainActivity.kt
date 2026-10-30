package `in`.attendance.attendance_app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity, not FlutterActivity: local_auth's BiometricPrompt needs a
// FragmentActivity host and otherwise fails before showing anything (fingerprint unlock
// silently never appeared).
class MainActivity : FlutterFragmentActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DeviceSecurityPlugin.CHANNEL)
      .setMethodCallHandler(DeviceSecurityPlugin(applicationContext))
  }
}
