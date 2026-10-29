import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/theme/branding.dart';
import 'app/theme/theme_providers.dart';
import 'core/notifications/punch_reminder.dart';
import 'core/notifications/push_service.dart';
import 'core/storage/secure_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Push is optional in development: without a Firebase config the app still runs.
  await PushService.tryInitialize();
  await PunchReminder.tryInitialize();
  final appearance = await _savedAppearance();
  runApp(ProviderScope(
    overrides: [
      initialBrandingProvider.overrideWithValue(appearance.branding),
      initialThemeModeProvider.overrideWithValue(appearance.mode),
    ],
    child: const AttendanceApp(),
  ));
}

/// The last company colours and the chosen light/dark mode, so the first frame already looks right.
Future<({Branding branding, ThemeMode mode})> _savedAppearance() async {
  try {
    final store = SecureStore();
    return (branding: Branding.decode(await store.read(SecureKeys.branding)), mode: themeModeFromName(await store.read(SecureKeys.themeMode)));
  } catch (e) {
    debugPrint('Saved appearance unavailable: $e');
    return (branding: Branding.defaults, mode: ThemeMode.system);
  }
}
