import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../../punch/data/punch_service.dart';
import '../../punch/presentation/punch_flow_screen.dart';

final punchContextProvider = FutureProvider.autoDispose<PunchContext>((ref) => ref.watch(punchServiceProvider).context());

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionControllerProvider).me;
    final ctx = ref.watch(punchContextProvider);
    return Scaffold(
      appBar: AppBar(title: Text(me?.companyName ?? 'Attendance'), actions: [IconButton(onPressed: () => ref.invalidate(punchContextProvider), icon: const Icon(Icons.refresh))]),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(punchContextProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Hello, ${me?.fullName.split(' ').first ?? ''}', style: Theme.of(context).textTheme.headlineSmall),
            Text(DateFormat('EEEE, d MMMM').format(DateTime.now()), style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            ctx.when(
              loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(ApiFailure.from(e).message))),
              data: (c) => _TodayCard(ctx: c, onPunched: () => ref.invalidate(punchContextProvider)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.ctx, required this.onPunched});

  final PunchContext ctx;
  final VoidCallback onPunched;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = ctx.today;
    final worked = today['workedMinutes'] as int? ?? 0;
    final status = today['status'] as String? ?? 'NOT_STARTED';
    final isIn = ctx.nextDirection == 'IN';
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Chip(label: Text(_label(status)), backgroundColor: scheme.secondaryContainer),
                  const Spacer(),
                  if (ctx.shift != null) Text('${ctx.shift!['startTime']}–${ctx.shift!['endTime']}', style: Theme.of(context).textTheme.bodySmall),
                ]),
                const SizedBox(height: 12),
                Text('${worked ~/ 60}h ${worked % 60}m', style: Theme.of(context).textTheme.displaySmall),
                Text('worked today${today['isLate'] == true ? ' · late' : ''}'),
                const SizedBox(height: 16),
                if (ctx.punches.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: ctx.punches.map((p) => Chip(avatar: Icon(p['direction'] == 'IN' ? Icons.login : Icons.logout, size: 16), label: Text(DateFormat('HH:mm').format(DateTime.parse(p['at'] as String).toLocal())))).toList(),
                  ),
                const SizedBox(height: 16),
                if (!ctx.punchAllowed)
                  Text(_blocked(ctx), style: TextStyle(color: scheme.error))
                else
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: isIn ? scheme.primary : scheme.tertiary),
                    onPressed: () async {
                      final ok = await context.push<bool>(Routes.punch);
                      if (ok == true) onPunched();
                    },
                    icon: Icon(isIn ? Icons.login : Icons.logout),
                    label: Text(isIn ? 'Punch in' : 'Punch out'),
                  ),
                const SizedBox(height: 8),
                Text(ctx.sites.isEmpty ? 'No work site assigned. Contact your employer.' : 'Punching works only at: ${ctx.sites.map((s) => s['name']).join(', ')}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _label(String status) => switch (status) {
        'NOT_STARTED' => 'Not punched yet',
        'IN_PROGRESS' => 'Working',
        'PRESENT' => 'Present',
        'HALF_DAY' => 'Half day',
        'ABSENT' => 'Absent',
        'LEAVE' => 'On leave',
        'HOLIDAY' => 'Holiday',
        'WEEKLY_OFF' => 'Weekly off',
        _ => status,
      };

  static String _blocked(PunchContext ctx) => switch (ctx.blockedReason) {
        'NON_WORKING_DAY' => ctx.dayType == 'HOLIDAY' ? 'Today is a holiday${ctx.holidayName != null ? ' (${ctx.holidayName})' : ''}. Punching is closed.' : 'Today is your weekly off. Punching is closed.',
        'ON_LEAVE' => 'You are on approved leave today.',
        _ => 'Punching is not available today.',
      };
}
