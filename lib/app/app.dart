import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/session_controller.dart';
import '../core/config/env.dart';
import '../core/notifications/notification_taps.dart';
import '../core/providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/branding.dart';
import 'theme/theme_providers.dart';

class AttendanceApp extends ConsumerStatefulWidget {
  const AttendanceApp({super.key});

  @override
  ConsumerState<AttendanceApp> createState() => _AttendanceAppState();
}

class _AttendanceAppState extends ConsumerState<AttendanceApp> with WidgetsBindingObserver {
  DateTime? _backgroundedAt;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = ref.read(routerProvider);
    _router.routerDelegate.addListener(_openTapped);
    NotificationTaps.pending.addListener(_openTapped);
    ref.listenManual(sessionControllerProvider.select((s) => s.phase), (_, _) => _openTapped());
    ref.listenManual(sessionControllerProvider, (_, session) => _syncBranding(session));
  }

  /// The company's colours follow the loaded profile; a released phone goes back to the defaults.
  void _syncBranding(SessionState session) {
    final me = session.me;
    final branding = ref.read(brandingProvider.notifier);
    if (me != null) {
      branding.apply(Branding.fromJson(me.company['branding']));
    } else if (session.phase == SessionPhase.needsActivation) {
      branding.reset();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.routerDelegate.removeListener(_openTapped);
    NotificationTaps.pending.removeListener(_openTapped);
    super.dispose();
  }

  /// Opens the screen of a tapped notification, but only once unlocked and past the gate screens
  /// (the redirect to home must land first, so the new screen stacks on home and back works).
  void _openTapped() {
    final data = NotificationTaps.pending.value;
    if (data == null || ref.read(sessionControllerProvider).phase != SessionPhase.ready) return;
    if (Routes.gates.contains(_router.routerDelegate.currentConfiguration.uri.path)) return;
    NotificationTaps.pending.value = null;
    final route = notificationRoute(data, extraTime: ref.read(sessionControllerProvider).me?.extraTimeEnabled ?? true);
    if (route == null) return;
    // Outside the listener callback, which may run while the router is notifying.
    Future.microtask(() {
      if (route == Routes.home) {
        _router.go(route);
      } else {
        _router.push<void>(route);
      }
    });
  }

  /// Re-lock when the app has been in the background for a while.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _backgroundedAt != null) {
      final session = ref.read(sessionControllerProvider.notifier);
      if (DateTime.now().difference(_backgroundedAt!) > const Duration(minutes: Env.relockAfterMinutes)) {
        session.relock();
      } else if (ref.read(sessionControllerProvider).phase == SessionPhase.ready) {
        // Pick up modules and branding the employer or platform changed while the app was in the background.
        session.refreshMe();
      }
      _backgroundedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final branding = ref.watch(brandingProvider);
    return MaterialApp.router(
      title: Env.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(branding),
      darkTheme: AppTheme.dark(branding),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
    );
  }
}
