import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/notifications/punch_reminder.dart';
import 'core/notifications/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Push is optional in development: without a Firebase config the app still runs.
  await PushService.tryInitialize();
  await PunchReminder.tryInitialize();
  runApp(const ProviderScope(child: AttendanceApp()));
}
