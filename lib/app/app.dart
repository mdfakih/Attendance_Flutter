import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/env.dart';
import '../core/providers.dart';
import 'router.dart';

class AttendanceApp extends ConsumerStatefulWidget {
  const AttendanceApp({super.key});

  @override
  ConsumerState<AttendanceApp> createState() => _AttendanceAppState();
}

class _AttendanceAppState extends ConsumerState<AttendanceApp> with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-lock when the app has been in the background for a while.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _backgroundedAt != null) {
      if (DateTime.now().difference(_backgroundedAt!) > const Duration(minutes: Env.relockAfterMinutes)) {
        ref.read(sessionControllerProvider.notifier).relock();
      }
      _backgroundedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1F5EFF));
    return MaterialApp.router(
      title: 'Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52))),
      ),
      routerConfig: router,
    );
  }
}
