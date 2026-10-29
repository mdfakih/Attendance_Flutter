import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_taps.dart';

/// "Did you forget to punch out?" is scheduled on the phone; the server only says when
/// (`reminderAt`). One fixed id, so every sync replaces the previous reminder.
abstract final class PunchReminder {
  static const type = 'PUNCH_REMINDER';
  static const _id = 7001;
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails('punch_reminder', 'Punch-out reminders',
        channelDescription: 'Reminds you to punch out after your shift ends.', importance: Importance.high, priority: Priority.high),
  );
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool _askedPermission = false;
  static Future<void> _queue = Future.value();

  /// Best-effort, like push: without the plugin the app still runs, just without reminders.
  static Future<void> tryInitialize() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestSoundPermission: false, requestBadgePermission: false),
        ),
        onDidReceiveNotificationResponse: (_) => NotificationTaps.add(const {'type': type}),
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) NotificationTaps.add(const {'type': type});
      _ready = true;
    } catch (e) {
      debugPrint('Punch reminder disabled: $e');
    }
  }

  /// When to remind, as an absolute UTC instant (no timezone database needed); null when there is nothing left to remind about.
  @visibleForTesting
  static tz.TZDateTime? scheduleTime(String? reminderAt, DateTime now) {
    final at = reminderAt == null ? null : DateTime.tryParse(reminderAt);
    if (at == null || !at.isAfter(now)) return null;
    return tz.TZDateTime.from(at, tz.UTC);
  }

  /// Schedules (or replaces) the reminder at [reminderAt], or cancels it when null. Never throws.
  /// Calls run one after another, so the latest server answer always wins.
  static Future<void> sync(String? reminderAt) => _queue = _queue.then((_) => _apply(reminderAt));

  static Future<void> _apply(String? reminderAt) async {
    if (!_ready) return;
    try {
      final at = scheduleTime(reminderAt, DateTime.now());
      await _plugin.cancel(id: _id);
      if (at == null) return;
      await _askPermissionOnce();
      // Inexact: needs no SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM; a few minutes late is fine for a reminder.
      await _plugin.zonedSchedule(
        id: _id,
        scheduledDate: at,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: 'Did you forget to punch out?',
        body: 'Your shift has ended. Open the app and punch out.',
        payload: type,
      );
    } catch (e) {
      debugPrint('Punch reminder not scheduled: $e');
    }
  }

  static Future<void> cancel() => sync(null);

  /// Android 13+ needs POST_NOTIFICATIONS at runtime. Push asks only when Firebase is set up, so ask here too (once per run).
  /// A failed ask (e.g. another permission dialog is open) still lets the reminder be scheduled.
  static Future<void> _askPermissionOnce() async {
    if (_askedPermission) return;
    _askedPermission = true;
    try {
      if (await Permission.notification.isDenied) await Permission.notification.request();
    } catch (e) {
      _askedPermission = false;
      debugPrint('Notification permission not requested: $e');
    }
  }
}
