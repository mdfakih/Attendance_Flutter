import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/branding.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/notifications/punch_reminder.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/theme_toggle.dart';
import '../../punch/data/punch_service.dart';
import '../../punch/presentation/punch_flow_screen.dart';
import 'widgets/today_view.dart';

final punchContextProvider = FutureProvider.autoDispose<PunchContext>((ref) async {
  final ctx = await ref.watch(punchServiceProvider).context();
  // The server no longer pushes "forgot to punch out?"; keep the phone's own reminder in step on every load.
  unawaited(PunchReminder.sync(ctx.reminderAt));
  return ctx;
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionControllerProvider).me;
    final ctx = ref.watch(punchContextProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(punchContextProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _Header(
                firstName: me?.fullName.split(' ').first ?? '',
                companyName: me?.companyName ?? '',
                logoUrl: Branding.fromJson(me?.company['branding']).logoUrl,
              ),
              const SizedBox(height: 20),
              ctx.when(
                skipLoadingOnRefresh: true,
                loading: () => const _TodaySkeleton(),
                error: (e, _) => Card(child: ErrorState(message: ApiFailure.from(e).message, onRetry: () => ref.invalidate(punchContextProvider))),
                data: (c) => TodayView(ctx: c, extraTime: me?.extraTimeEnabled ?? true, onChanged: () => ref.invalidate(punchContextProvider)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.firstName, required this.companyName, this.logoUrl});

  final String firstName;
  final String companyName;
  final String? logoUrl;

  static String _greeting(DateTime now) => now.hour < 12 ? 'Good morning' : (now.hour < 17 ? 'Good afternoon' : 'Good evening');

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    return Row(
      children: [
        CompanyLogo(name: companyName.isEmpty ? '?' : companyName, logoUrl: logoUrl, size: 48),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(firstName.isEmpty ? _greeting(now) : '${_greeting(now)}, $firstName', style: text.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${DateFormat('EEEE, d MMMM').format(now)}${companyName.isEmpty ? '' : ' · $companyName'}',
                  style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const ThemeToggleButton(),
      ],
    );
  }
}

class _TodaySkeleton extends StatelessWidget {
  const _TodaySkeleton();

  @override
  Widget build(BuildContext context) => const Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkeletonBox(height: 300, radius: 24),
            SizedBox(height: 20),
            SkeletonBox(width: 160, height: 16),
            SizedBox(height: 12),
            SkeletonBox(height: 72, radius: 18),
          ],
        ),
      );
}
