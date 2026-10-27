import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/providers.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionControllerProvider).me;
    final tabs = <({String route, IconData icon, String label})>[
      (route: Routes.home, icon: Icons.home_outlined, label: 'Home'),
      (route: Routes.attendance, icon: Icons.calendar_month_outlined, label: 'Attendance'),
      if (me?.has('LEAVE') ?? false) (route: Routes.leave, icon: Icons.event_busy_outlined, label: 'Leave'),
      if (me?.has('EMPLOYEE_EARNINGS_VIEW') ?? false) (route: Routes.earnings, icon: Icons.payments_outlined, label: 'Earnings'),
      (route: Routes.profile, icon: Icons.person_outline, label: 'Profile'),
    ];
    final location = GoRouterState.of(context).matchedLocation;
    final index = tabs.indexWhere((t) => location.startsWith(t.route)).clamp(0, tabs.length - 1);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(tabs[i].route),
        destinations: tabs.map((t) => NavigationDestination(icon: Icon(t.icon), label: t.label)).toList(),
      ),
    );
  }
}
