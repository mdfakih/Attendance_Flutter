import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'notification_taps.dart';

/// Firebase is used for push only (no Firebase Auth). Initialisation is best-effort so the
/// app works before `google-services.json` is added.
abstract final class PushService {
  static bool _ready = false;

  static Future<void> tryInitialize() async {
    try {
      await Firebase.initializeApp();
      _ready = true;
      // A tapped push (app in background or closed) opens its screen once the app is unlocked.
      FirebaseMessaging.onMessageOpenedApp.listen((m) => NotificationTaps.add(m.data));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) NotificationTaps.add(initial.data);
    } catch (e) {
      debugPrint('Push disabled: $e');
    }
  }

  static bool get isReady => _ready;

  /// Returns the FCM registration token after asking for permission (Android 13+). Null when push is off.
  ///
  /// `getToken` is deprecated in favour of `register()` + `onRegistered`, which yield a Firebase
  /// Installation ID. The backend sends with the Admin SDK's `send({ token })`, which still needs
  /// the registration token, so we keep this call until the server moves to installation IDs.
  static Future<String?> token() async {
    if (!_ready) return null;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      // ignore: deprecated_member_use
      return await messaging.getToken();
    } catch (_) {
      return null;
    }
  }
}
