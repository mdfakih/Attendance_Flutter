import 'package:flutter/foundation.dart';

/// Data of the last tapped notification (FCM push or local reminder), held until the app is
/// unlocked and can navigate. `data['type']` says which screen to open.
abstract final class NotificationTaps {
  static final pending = ValueNotifier<Map<String, dynamic>?>(null);

  static void add(Map<String, dynamic> data) => pending.value = Map.unmodifiable(data);
}
