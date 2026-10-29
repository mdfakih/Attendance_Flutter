import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';

/// Days of the month with time outside working hours, newest first, each with the employee's request (or null).
final regularizationMonthProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, month) async => (await ref.watch(apiProvider).get<List<dynamic>>('/v1/mobile/regularizations', query: {'month': month})).cast<Map<String, dynamic>>(),
);

/// "1h 20m", "45m", "2h".
String fmtDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// Label for a day's `regState`.
String regStateLabel(String state) => switch (state) {
      'AVAILABLE' => 'Not counted',
      'REQUESTED' => 'Waiting for approval',
      'APPROVED' => 'Counted',
      'REJECTED' => 'Not approved',
      _ => state,
    };

Color regStateColor(String state, ColorScheme scheme) => switch (state) {
      'AVAILABLE' => Colors.orange,
      'REQUESTED' => Colors.blue,
      'APPROVED' => Colors.green,
      'REJECTED' => scheme.error,
      _ => Colors.grey,
    };

/// Null when acceptable; mirrors the server's 5–500 character rule.
String? regularizationReasonError(String reason) {
  final length = reason.trim().length;
  if (length < 5) return 'Give a reason of at least 5 characters.';
  if (length > 500) return 'Keep the reason under 500 characters.';
  return null;
}

/// The "ask to count this time" form. True when the request was sent.
Future<bool> showRegularizationRequestSheet(BuildContext context, {required String date, required int outsideMinutes}) async =>
    await showModalBottomSheet<bool>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => _RequestSheet(date: date, outsideMinutes: outsideMinutes)) == true;

String? _hhmm(Object? iso) => iso is String ? DateFormat('HH:mm').format(DateTime.parse(iso).toLocal()) : null;

/// Punch time outside working hours is recorded but not counted; here the employee asks for it to be counted.
class RegularizationScreen extends ConsumerStatefulWidget {
  const RegularizationScreen({super.key, this.focusDate});

  /// 'YYYY-MM-DD' (from a notification or the calendar): its month opens and the day is highlighted.
  final String? focusDate;

  @override
  ConsumerState<RegularizationScreen> createState() => _RegularizationScreenState();
}

class _RegularizationScreenState extends ConsumerState<RegularizationScreen> {
  late DateTime _month;
  String? _focusDate;
  final _focusKey = GlobalKey();
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    final focus = DateTime.tryParse(widget.focusDate ?? '');
    final now = DateTime.now();
    final start = focus != null && focus.isBefore(now) ? focus : now;
    _focusDate = focus == null ? null : DateFormat('yyyy-MM-dd').format(focus);
    _month = DateTime(start.year, start.month);
  }

  /// Brings the focused day into view once, after its card is laid out.
  void _scrollToFocus() {
    if (_scrolled || _focusDate == null) return;
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _focusKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final key = DateFormat('yyyy-MM').format(_month);
    final days = ref.watch(regularizationMonthProvider(key));
    final isCurrent = key == DateFormat('yyyy-MM').format(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Time outside working hours')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(regularizationMonthProvider(key)),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)), icon: const Icon(Icons.chevron_left)),
                Text(DateFormat('MMMM yyyy').format(_month), style: Theme.of(context).textTheme.titleMedium),
                IconButton(onPressed: isCurrent ? null : () => setState(() => _month = DateTime(_month.year, _month.month + 1)), icon: const Icon(Icons.chevron_right)),
              ],
            ),
            Text('Punches before your working hours start or after they end are recorded but not counted. If it was work, ask your employer to count it. Under 15 minutes on either side is ignored.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            days.when(
              loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text(ApiFailure.from(e).message)),
              data: (rows) {
                if (rows.isEmpty) return const Padding(padding: EdgeInsets.all(32), child: Text('No time outside working hours this month.', textAlign: TextAlign.center));
                _scrollToFocus();
                return Column(
                  children: rows.map((d) {
                    final focused = d['date'] == _focusDate;
                    return _DayCard(
                      key: focused ? _focusKey : ValueKey(d['date']),
                      day: d,
                      highlighted: focused,
                      onChanged: () {
                        if (mounted) ref.invalidate(regularizationMonthProvider(key));
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCard extends ConsumerStatefulWidget {
  const _DayCard({super.key, required this.day, required this.highlighted, required this.onChanged});

  final Map<String, dynamic> day;
  final bool highlighted;
  final VoidCallback onChanged;

  @override
  ConsumerState<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends ConsumerState<_DayCard> {
  bool _busy = false;

  Map<String, dynamic> get day => widget.day;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final state = day['regState'] as String? ?? 'NOT_APPLICABLE';
    final request = day['request'] as Map<String, dynamic>?;
    final outside = day['outsideMinutes'] as int? ?? 0;
    final early = day['outsideEarlyMinutes'] as int? ?? 0;
    final late = day['outsideLateMinutes'] as int? ?? 0;
    final start = _hhmm(day['expectedStartAt']);
    final end = _hhmm(day['expectedEndAt']);
    return Card(
      shape: widget.highlighted ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: scheme.primary, width: 2)) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(DateFormat('EEE, d MMM').format(DateTime.parse(day['date'] as String)), style: text.titleMedium)),
              Chip(label: Text(regStateLabel(state)), visualDensity: VisualDensity.compact, side: BorderSide(color: regStateColor(state, scheme))),
            ]),
            if (start != null && end != null) Text('Working hours $start–$end'),
            Text('Punched ${_hhmm(day['firstPunchAt']) ?? '—'} → ${_hhmm(day['lastPunchAt']) ?? '—'}'),
            const SizedBox(height: 8),
            Text('${fmtDuration(outside)} outside working hours', style: text.titleSmall),
            Text([if (early > 0) '${fmtDuration(early)} before start', if (late > 0) '${fmtDuration(late)} after end'].join(' · '), style: text.bodySmall),
            if (request != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Your reason: ${request['reason']}', style: text.bodySmall)),
            ..._outcome(state, request, outside),
          ],
        ),
      ),
    );
  }

  List<Widget> _outcome(String state, Map<String, dynamic>? request, int outside) {
    final note = request?['decisionNote'] as String?;
    final noteLine = note == null || note.isEmpty ? null : Text('Note from your employer: $note');
    switch (state) {
      case 'AVAILABLE':
        return [
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () async {
              if (await showRegularizationRequestSheet(context, date: day['date'] as String, outsideMinutes: outside)) widget.onChanged();
            },
            icon: const Icon(Icons.more_time),
            label: const Text('Ask to count this time'),
          ),
        ];
      case 'REQUESTED':
        return [
          const SizedBox(height: 8),
          Row(children: [
            const Expanded(child: Text('Waiting for your employer.')),
            if (request != null && request['status'] == 'PENDING') TextButton(onPressed: _busy ? null : () => _withdraw(request['id'] as String), child: const Text('Withdraw')),
          ]),
        ];
      case 'APPROVED':
        final approved = day['regApprovedMinutes'] as int? ?? request?['approvedMinutes'] as int? ?? 0;
        return [
          const SizedBox(height: 8),
          Text(approved < outside ? '${fmtDuration(approved)} of ${fmtDuration(outside)} now counts as working time.' : '${fmtDuration(approved)} now counts as working time.',
              style: const TextStyle(color: Colors.green)),
          ?noteLine,
        ];
      case 'REJECTED':
        return [
          const SizedBox(height: 8),
          Text('Your employer did not count this time.', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ?noteLine,
        ];
      default:
        return const [];
    }
  }

  Future<void> _withdraw(String id) async {
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).post<Map<String, dynamic>>('/v1/mobile/regularizations/$id/cancel');
      widget.onChanged();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiFailure.from(e).message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _RequestSheet extends ConsumerStatefulWidget {
  const _RequestSheet({required this.date, required this.outsideMinutes});

  final String date;
  final int outsideMinutes;

  @override
  ConsumerState<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends ConsumerState<_RequestSheet> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final invalid = regularizationReasonError(_reason.text);
    if (invalid != null) return setState(() => _error = invalid);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).post<Map<String, dynamic>>('/v1/mobile/regularizations', body: {'date': widget.date, 'reason': _reason.text.trim()});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiFailure.from(e).message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = DateFormat('EEE, d MMM').format(DateTime.parse(widget.date));
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ask to count this time', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('${fmtDuration(widget.outsideMinutes)} on $day was outside your working hours, so it is not counted. If it was work, tell your employer why.'),
          const SizedBox(height: 16),
          TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason'), maxLines: 3, maxLength: 500, textCapitalization: TextCapitalization.sentences),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _submit, child: const Text('Send request')),
        ],
      ),
    );
  }
}
