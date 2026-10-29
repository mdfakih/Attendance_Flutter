import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_palette.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/states.dart';
import '../../regularization/presentation/regularization_screen.dart';
import 'day_sheet.dart';

final monthViewProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, month) => ref.watch(apiProvider).get<Map<String, dynamic>>('/v1/mobile/attendance/month', query: {'month': month}),
);
final dayDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, date) => ref.watch(apiProvider).get<Map<String, dynamic>>('/v1/mobile/attendance/days/$date'),
);

const statusLabels = {
  'PRESENT': 'Present', 'HALF_DAY': 'Half day', 'ABSENT': 'Absent', 'LEAVE': 'Leave', 'HALF_LEAVE': 'Half-day leave',
  'HOLIDAY': 'Holiday', 'WEEKLY_OFF': 'Weekly off', 'IN_PROGRESS': 'Working', 'NOT_STARTED': 'Not punched', 'MISSING_OUT': 'Missing out',
};

Color statusColor(String status, BuildContext context) {
  final palette = AppPalette.of(context);
  return switch (status) {
    'PRESENT' => palette.success,
    'IN_PROGRESS' => palette.info,
    'HALF_DAY' || 'HALF_LEAVE' => palette.warning,
    'ABSENT' || 'MISSING_OUT' => Theme.of(context).colorScheme.error,
    'LEAVE' => palette.leave,
    _ => palette.neutral,
  };
}

String fmtMinutes(int m) => m == 0 ? '0h' : '${m ~/ 60}h ${m % 60 == 0 ? '' : '${m % 60}m'}'.trim();

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime? _selected;

  String get _month => DateFormat('yyyy-MM').format(_focused);

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(monthViewProvider(_month));
    final extraTime = ref.watch(sessionControllerProvider.select((s) => s.me?.extraTimeEnabled ?? true));
    final days = <String, Map<String, dynamic>>{};
    for (final d in (view.valueOrNull?['days'] as List? ?? const [])) {
      days[(d as Map)['date'] as String] = d.cast<String, dynamic>();
    }
    final totals = view.valueOrNull?['totals'] as Map<String, dynamic>?;
    final outside = days.values.fold<int>(0, (sum, d) => sum + (d['outsideMinutes'] as int? ?? 0));
    return Scaffold(
      appBar: AppBar(title: const Text('My attendance'), actions: [
        if (extraTime) IconButton(tooltip: 'Time outside working hours', onPressed: () => context.push<void>(Routes.regularization), icon: const Icon(Icons.more_time_rounded)),
      ]),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(monthViewProvider(_month)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: _calendar(context, days),
              ),
            ),
            const SizedBox(height: 12),
            const _Legend(),
            const SectionHeader('This month'),
            if (view.isLoading && totals == null) const _TotalsSkeleton(),
            if (view.hasError && totals == null)
              Card(child: ErrorState(message: ApiFailure.from(view.error!).message, onRetry: () => ref.invalidate(monthViewProvider(_month)), compact: true)),
            if (totals != null) _Totals(totals: totals, outside: outside),
          ],
        ),
      ),
    );
  }

  Widget _calendar(BuildContext context, Map<String, Map<String, dynamic>> days) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return TableCalendar<void>(
      firstDay: DateTime(2024),
      lastDay: DateTime.now().add(const Duration(days: 31)),
      focusedDay: _focused,
      rowHeight: 48,
      selectedDayPredicate: (d) => _selected != null && isSameDay(d, _selected),
      onDaySelected: (sel, foc) {
        setState(() {
          _selected = sel;
          _focused = foc;
        });
        _openDay(DateFormat('yyyy-MM-dd').format(sel));
      },
      onPageChanged: (foc) => setState(() => _focused = foc),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: text.titleMedium ?? const TextStyle(),
        leftChevronIcon: Icon(Icons.chevron_left_rounded, color: scheme.onSurface),
        rightChevronIcon: Icon(Icons.chevron_right_rounded, color: scheme.onSurface),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: text.labelSmall!.copyWith(color: scheme.onSurfaceVariant),
        weekendStyle: text.labelSmall!.copyWith(color: scheme.onSurfaceVariant),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        defaultTextStyle: text.bodyMedium!,
        weekendTextStyle: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
        todayDecoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.14), shape: BoxShape.circle),
        todayTextStyle: text.bodyMedium!.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
        selectedDecoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
        selectedTextStyle: text.bodyMedium!.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w700),
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, _) {
          final d = days[DateFormat('yyyy-MM-dd').format(date)];
          if (d == null) return null;
          return Positioned(
            bottom: 5,
            child: Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor(d['status'] as String, context))),
          );
        },
      ),
    );
  }

  void _openDay(String date) {
    showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => DaySheet(date: date));
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final items = ['PRESENT', 'HALF_DAY', 'ABSENT', 'LEAVE', 'WEEKLY_OFF'];
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: items
          .map((s) => Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor(s, context), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(s == 'WEEKLY_OFF' ? 'Off / holiday' : statusLabels[s]!, style: Theme.of(context).textTheme.bodySmall),
              ]))
          .toList(),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.totals, required this.outside});

  final Map<String, dynamic> totals;
  final int outside;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tiles = <({String label, String value, Color color, IconData icon})>[
      (label: 'Present', value: '${totals['present']}', color: palette.success, icon: Icons.check_circle_rounded),
      (label: 'Half day', value: '${totals['halfDay']}', color: palette.warning, icon: Icons.timelapse_rounded),
      (label: 'Absent', value: '${totals['absent']}', color: scheme.error, icon: Icons.cancel_rounded),
      (label: 'Leave', value: '${totals['leave']}', color: palette.leave, icon: Icons.beach_access_rounded),
      (label: 'Late', value: '${totals['late']}', color: palette.neutral, icon: Icons.alarm_rounded),
      (label: 'Hours', value: fmtMinutes(totals['workedMinutes'] as int? ?? 0), color: scheme.primary, icon: Icons.schedule_rounded),
      if (outside > 0) (label: 'Outside hours', value: fmtDuration(outside), color: palette.warning, icon: Icons.more_time_rounded),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth - 20) / 3;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: tiles.map((t) => SizedBox(width: width, child: _StatTile(label: t.label, value: t.value, color: t.color, icon: t.icon))).toList(),
      );
    });
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.color, required this.icon});

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: text.titleLarge)),
            Text(label, style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _TotalsSkeleton extends StatelessWidget {
  const _TotalsSkeleton();

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final width = (constraints.maxWidth - 20) / 3;
        return Shimmer(
          child: Wrap(spacing: 10, runSpacing: 10, children: List.generate(6, (_) => SkeletonBox(width: width, height: 86, radius: 18))),
        );
      });
}
