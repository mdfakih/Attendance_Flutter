import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../regularization/presentation/regularization_screen.dart';
import 'calendar_screen.dart';

/// One day's status, worked time, time outside working hours and punches.
class DaySheet extends ConsumerWidget {
  const DaySheet({super.key, required this.date, this.holidayName});

  final String date;

  /// From the month view; an upcoming holiday has no stored day yet.
  final String? holidayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(dayDetailProvider(date));
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('EEEE, d MMMM').format(DateTime.parse(date)), style: text.titleLarge),
            const SizedBox(height: 12),
            detail.when(
              loading: () => const SkeletonList(count: 3),
              error: (e, _) => ErrorState(message: ApiFailure.from(e).message, onRetry: () => ref.invalidate(dayDetailProvider(date)), compact: true),
              data: (d) => _Body(date: date, detail: d, holidayName: holidayName),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.date, required this.detail, this.holidayName});

  final String date;
  final Map<String, dynamic> detail;
  final String? holidayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final day = detail['day'] as Map<String, dynamic>?;
    final punches = (detail['punches'] as List).cast<Map<String, dynamic>>();
    final status = day?['status'] as String? ?? (holidayName != null ? 'HOLIDAY' : 'NOT_STARTED');
    final extraTime = ref.watch(sessionControllerProvider.select((s) => s.me?.extraTimeEnabled ?? true));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          StatusPill(label: statusLabels[status] ?? status, color: statusColor(status, context)),
          if (day != null)
            Text('${fmtMinutes(day['workedMinutes'] as int)} worked${day['isLate'] == true ? ' · ${day['lateMinutes']} min late' : ''}', style: text.bodyMedium),
        ]),
        if (holidayName != null && status == 'HOLIDAY') Padding(padding: const EdgeInsets.only(top: 6), child: Text(holidayName!, style: text.bodyMedium)),
        if (day?['statusSource'] == 'MANUAL') Padding(padding: const EdgeInsets.only(top: 6), child: Text('Set by your employer', style: text.bodySmall)),
        if (day != null && (day['outsideMinutes'] as int? ?? 0) > 0) _Outside(date: date, day: day, canAsk: extraTime),
        const SizedBox(height: 16),
        Text('Punches', style: text.titleSmall),
        const SizedBox(height: 4),
        if (punches.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('No punches on this day.', style: text.bodyMedium)),
        for (final p in punches) _PunchRow(punch: p),
      ],
    );
  }
}

class _PunchRow extends StatelessWidget {
  const _PunchRow({required this.punch});

  final Map<String, dynamic> punch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIn = punch['direction'] == 'IN';
    final thumb = punch['thumbUrl'] as String?;
    final placeholder = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Icon(isIn ? Icons.login_rounded : Icons.logout_rounded, color: scheme.primary),
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: thumb == null
          ? placeholder
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(thumb, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
            ),
      title: Text('${isIn ? 'Punch in' : 'Punch out'} · ${DateFormat('HH:mm').format(DateTime.parse(punch['serverTime'] as String).toLocal())}'),
      subtitle: Text([(punch['site'] as Map?)?['name'], if (punch['distanceM'] != null) '${punch['distanceM']} m away'].whereType<String>().join(' · ')),
    );
  }
}

/// Punch time outside working hours: shown, but counted only once the employer approves it.
class _Outside extends ConsumerWidget {
  const _Outside({required this.date, required this.day, required this.canAsk});

  final String date;
  final Map<String, dynamic> day;
  final bool canAsk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final state = day['regState'] as String? ?? 'NOT_APPLICABLE';
    final early = day['outsideEarlyMinutes'] as int? ?? 0;
    final late = day['outsideLateMinutes'] as int? ?? 0;
    final parts = [if (early > 0) '${fmtDuration(early)} before start', if (late > 0) '${fmtDuration(late)} after end'].join(', ');
    final outcome = state == 'APPROVED' ? '${fmtDuration(day['regApprovedMinutes'] as int? ?? 0)} counted' : regStateLabel(state);
    final color = regStateColor(state, scheme);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(Icons.more_time_rounded, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${fmtDuration(day['outsideMinutes'] as int)} outside working hours${parts.isEmpty ? '' : ' ($parts)'}${state == 'NOT_APPLICABLE' ? '' : ' · $outcome'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        if (canAsk && state != 'NOT_APPLICABLE')
          TextButton(
            onPressed: () async {
              await context.push<void>(Routes.regularizationOn(date));
              if (!context.mounted) return;
              ref.invalidate(dayDetailProvider(date));
              ref.invalidate(monthViewProvider);
            },
            child: Text(state == 'AVAILABLE' ? 'Ask to count' : 'View'),
          ),
      ]),
    );
  }
}
