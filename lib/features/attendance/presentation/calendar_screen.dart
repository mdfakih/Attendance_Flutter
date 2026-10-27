import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';

final monthViewProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, month) => ref.watch(apiProvider).get<Map<String, dynamic>>('/v1/mobile/attendance/month', query: {'month': month}),
);
final dayDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, date) => ref.watch(apiProvider).get<Map<String, dynamic>>('/v1/mobile/attendance/days/$date'),
);

const _statusLabel = {
  'PRESENT': 'Present', 'HALF_DAY': 'Half day', 'ABSENT': 'Absent', 'LEAVE': 'Leave', 'HALF_LEAVE': 'Half-day leave',
  'HOLIDAY': 'Holiday', 'WEEKLY_OFF': 'Weekly off', 'IN_PROGRESS': 'Working', 'NOT_STARTED': 'Not punched', 'MISSING_OUT': 'Missing out',
};

Color statusColor(String status, ColorScheme scheme) => switch (status) {
      'PRESENT' => Colors.green,
      'IN_PROGRESS' => Colors.blue,
      'HALF_DAY' || 'HALF_LEAVE' => Colors.orange,
      'ABSENT' || 'MISSING_OUT' => scheme.error,
      'LEAVE' => Colors.purple,
      _ => Colors.grey,
    };

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
    final scheme = Theme.of(context).colorScheme;
    final days = <String, Map<String, dynamic>>{};
    for (final d in (view.valueOrNull?['days'] as List? ?? const [])) {
      days[(d as Map)['date'] as String] = d.cast<String, dynamic>();
    }
    final totals = view.valueOrNull?['totals'] as Map<String, dynamic>?;
    return Scaffold(
      appBar: AppBar(title: const Text('My attendance')),
      body: ListView(
        children: [
          TableCalendar<void>(
            firstDay: DateTime(2024),
            lastDay: DateTime.now().add(const Duration(days: 31)),
            focusedDay: _focused,
            selectedDayPredicate: (d) => _selected != null && isSameDay(d, _selected),
            onDaySelected: (sel, foc) {
              setState(() {
                _selected = sel;
                _focused = foc;
              });
              _openDay(DateFormat('yyyy-MM-dd').format(sel));
            },
            onPageChanged: (foc) => setState(() => _focused = foc),
            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, _) {
                final d = days[DateFormat('yyyy-MM-dd').format(date)];
                if (d == null) return null;
                return Positioned(bottom: 4, child: Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor(d['status'] as String, scheme))));
              },
            ),
          ),
          if (view.isLoading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          if (view.hasError) Padding(padding: const EdgeInsets.all(16), child: Text(ApiFailure.from(view.error!).message)),
          if (totals != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('Present ${totals['present']}', Colors.green),
                  _chip('Half ${totals['halfDay']}', Colors.orange),
                  _chip('Absent ${totals['absent']}', scheme.error),
                  _chip('Leave ${totals['leave']}', Colors.purple),
                  _chip('Late ${totals['late']}', Colors.grey),
                  _chip('Hours ${fmtMinutes(totals['workedMinutes'] as int)}', Colors.blueGrey),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) => Chip(label: Text(text), side: BorderSide(color: color), avatar: CircleAvatar(backgroundColor: color, radius: 5));

  void _openDay(String date) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _DaySheet(date: date),
    );
  }
}

class _DaySheet extends ConsumerWidget {
  const _DaySheet({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(dayDetailProvider(date));
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: detail.when(
        loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text(ApiFailure.from(e).message),
        data: (d) {
          final day = d['day'] as Map<String, dynamic>?;
          final punches = (d['punches'] as List).cast<Map<String, dynamic>>();
          final status = day?['status'] as String? ?? 'NOT_STARTED';
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat('EEEE, d MMMM').format(DateTime.parse(date)), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Row(children: [
                Chip(label: Text(_statusLabel[status] ?? status), backgroundColor: statusColor(status, scheme).withValues(alpha: 0.15)),
                const SizedBox(width: 8),
                if (day != null) Text('${fmtMinutes(day['workedMinutes'] as int)} worked${day['isLate'] == true ? ' · ${day['lateMinutes']} min late' : ''}'),
              ]),
              if (day?['statusSource'] == 'MANUAL') const Padding(padding: EdgeInsets.only(top: 4), child: Text('Set by your employer', style: TextStyle(fontSize: 12))),
              const SizedBox(height: 12),
              if (punches.isEmpty) const Text('No punches on this day.'),
              for (final p in punches)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: p['thumbUrl'] != null ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(p['thumbUrl'] as String, width: 48, height: 48, fit: BoxFit.cover)) : const Icon(Icons.fingerprint),
                  title: Text('${p['direction'] == 'IN' ? 'Punch in' : 'Punch out'} · ${DateFormat('HH:mm').format(DateTime.parse(p['serverTime'] as String).toLocal())}'),
                  subtitle: Text([(p['site'] as Map?)?['name'], if (p['distanceM'] != null) '${p['distanceM']} m away'].whereType<String>().join(' · ')),
                ),
            ],
          );
        },
      ),
    );
  }
}
