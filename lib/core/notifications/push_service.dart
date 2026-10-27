import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Firebase is used for push only (no Firebase Auth). Initialisation is best-effort so the
/// app works before `google-services.json` is added.
abstract final class PushService {
  static bool _ready = false;

  static Future<void> tryInitialize() async {
    try {
      await Firebase.initializeApp();
      _ready = true;
    } catch (e) {
      debugPrint('Push disabled: $e');
    }
  }

  static bool get isReady => _ready;

  /// Returns the FCM token after asking for permission (Android 13+). Null when push is off.
  static Future<String?> token() async {
    if (!_ready) return null;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      return await messaging.getToken();
    } catch (_) {
      return null;
    }
  }
}
