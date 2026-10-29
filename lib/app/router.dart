import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/session_controller.dart';
import '../core/notifications/punch_reminder.dart';
import '../core/providers.dart';
import '../features/activation/presentation/activation_screen.dart';
import '../features/activation/presentation/pending_approval_screen.dart';
import '../features/app_lock/presentation/pin_reset_screen.dart';
import '../features/app_lock/presentation/set_pin_screen.dart';
import '../features/app_lock/presentation/unlock_screen.dart';
import '../features/attendance/presentation/calendar_screen.dart';
import '../features/earnings/presentation/earnings_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/leave/presentation/leave_screen.dart';
import '../features/onboarding/presentation/consent_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/punch/presentation/punch_flow_screen.dart';
import '../features/regularization/presentation/regularization_screen.dart';
import '../features/shell/home_shell.dart';
import '../shared/widgets/app_loader.dart';

abstract final class Routes {
  static const splash = '/';
  static const activation = '/activate';
  static const pending = '/pending-approval';
  static const setPin = '/set-pin';
  static const unlock = '/unlock';
  static const pinReset = '/pin-reset';
  static const consent = '/consent';
  static const home = '/home';
  static const punch = '/home/punch';
  static const attendance = '/attendance';
  static const regularization = '/attendance/regularization';
  static const leave = '/leave';
  static const earnings = '/earnings';
  static const profile = '/profile';

  /// Screens before the session is ready; once ready they redirect to home.
  static const gates = {splash, activation, pending, setPin, unlock, consent};

  /// Regularization screen, optionally opened on a day ('YYYY-MM-DD').
  static String regularizationOn(String? date) => date == null ? regularization : Uri(path: regularization, queryParameters: {'date': date}).toString();
}

/// Screen for a tapped notification (FCM push, in-app list or local reminder) by its `data.type`; null = none.
/// With extra time requests switched off, their notifications open home instead.
String? notificationRoute(Map<String, dynamic> data, {bool extraTime = true}) {
  final date = data['date'];
  return switch (data['type']) {
    'OUTSIDE_HOURS' || 'REGULARIZATION_DECISION' => extraTime ? Routes.regularizationOn(date is String ? date : null) : Routes.home,
    PunchReminder.type => Routes.home,
    _ => null,
  };
}

String? _redirectFor(SessionState session, String location) {
  switch (session.phase) {
    case SessionPhase.loading:
      return location == Routes.splash ? null : Routes.splash;
    case SessionPhase.needsActivation:
      return location == Routes.activation || location == Routes.pinReset ? null : Routes.activation;
    case SessionPhase.pendingApproval:
      return location == Routes.pending ? null : Routes.pending;
    case SessionPhase.needsPinSetup:
      return location == Routes.setPin ? null : Routes.setPin;
    case SessionPhase.locked:
      return location == Routes.unlock || location == Routes.pinReset ? null : Routes.unlock;
    case SessionPhase.needsConsent:
      return location == Routes.consent ? null : Routes.consent;
    case SessionPhase.ready:
      if (location == Routes.regularization && !(session.me?.extraTimeEnabled ?? true)) return Routes.home;
      return Routes.gates.contains(location) ? Routes.home : null;
  }
}

/// Listenable bridge so GoRouter re-evaluates redirects when the session phase changes.
class _SessionNotifier extends ChangeNotifier {
  _SessionNotifier(Ref ref) {
    ref.listen(sessionControllerProvider.select((s) => s.phase), (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _SessionNotifier(ref);
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: notifier,
    redirect: (context, state) => _redirectFor(ref.read(sessionControllerProvider), state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const BrandedSplash()),
      GoRoute(path: Routes.activation, builder: (_, _) => const ActivationScreen()),
      GoRoute(path: Routes.pending, builder: (_, _) => const PendingApprovalScreen()),
      GoRoute(path: Routes.setPin, builder: (_, _) => const SetPinScreen()),
      GoRoute(path: Routes.unlock, builder: (_, _) => const UnlockScreen()),
      GoRoute(path: Routes.pinReset, builder: (_, _) => const PinResetScreen()),
      GoRoute(path: Routes.consent, builder: (_, _) => const ConsentScreen()),
      GoRoute(path: Routes.punch, builder: (_, _) => const PunchFlowScreen()),
      GoRoute(path: Routes.regularization, builder: (_, state) => RegularizationScreen(focusDate: state.uri.queryParameters['date'])),
      ShellRoute(
        builder: (_, _, child) => HomeShell(child: child),
        routes: [
          GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
          GoRoute(path: Routes.attendance, builder: (_, _) => const CalendarScreen()),
          GoRoute(path: Routes.leave, builder: (_, _) => const LeaveScreen()),
          GoRoute(path: Routes.earnings, builder: (_, _) => const EarningsScreen()),
          GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
        ],
      ),
    ],
  );
});
