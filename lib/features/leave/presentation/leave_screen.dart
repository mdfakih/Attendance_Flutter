import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';

final leaveBalancesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async => (await ref.watch(apiProvider).get<List<dynamic>>('/v1/mobile/leave/balances')).cast<Map<String, dynamic>>(),
);
final leaveRequestsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async => (await ref.watch(apiProvider).get<List<dynamic>>('/v1/mobile/leave/requests')).cast<Map<String, dynamic>>(),
);

class LeaveScreen extends ConsumerWidget {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(leaveBalancesProvider);
    final requests = ref.watch(leaveRequestsProvider);
    final fmt = DateFormat('d MMM');
    return Scaffold(
      appBar: AppBar(title: const Text('Leave')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final applied = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => const _ApplySheet());
          if (applied == true) {
            ref.invalidate(leaveBalancesProvider);
            ref.invalidate(leaveRequestsProvider);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Apply'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(leaveBalancesProvider);
          ref.invalidate(leaveRequestsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Balances', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            balances.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(ApiFailure.from(e).message),
              data: (rows) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: rows
                    .map((b) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(children: [
                              Text(b['unlimited'] == true ? '∞' : '${(b['balance'] as num) - (b['pending'] as num)}', style: Theme.of(context).textTheme.headlineSmall),
                              Text(b['name'] as String, style: Theme.of(context).textTheme.bodySmall),
                            ]),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 24),
            Text('My requests', style: Theme.of(context).textTheme.titleMedium),
            requests.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(ApiFailure.from(e).message),
              data: (rows) => rows.isEmpty
                  ? const Padding(padding: EdgeInsets.all(16), child: Text('No leave requests yet.'))
                  : Column(
                      children: rows.map((r) {
                        final status = r['status'] as String;
                        return ListTile(
                          title: Text('${(r['leaveType'] as Map?)?['name']} · ${r['days']} day(s)'),
                          subtitle: Text('${fmt.format(DateTime.parse(r['fromDate'] as String))}${r['toDate'] != r['fromDate'] ? ' → ${fmt.format(DateTime.parse(r['toDate'] as String))}' : ''}\n${r['reason']}'),
                          isThreeLine: true,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Chip(label: Text(status), visualDensity: VisualDensity.compact),
                              if (status == 'PENDING' || status == 'APPROVED')
                                TextButton(
                                  onPressed: () async {
                                    try {
                                      await ref.read(apiProvider).post<Map<String, dynamic>>('/v1/mobile/leave/requests/${r['id']}/cancel');
                                      ref.invalidate(leaveRequestsProvider);
                                      ref.invalidate(leaveBalancesProvider);
                                    } catch (e) {
                                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiFailure.from(e).message)));
                                    }
                                  },
                                  child: const Text('Cancel'),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _ApplySheet extends ConsumerStatefulWidget {
  const _ApplySheet();

  @override
  ConsumerState<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends ConsumerState<_ApplySheet> {
  String? _typeId;
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  String _fromPart = 'FULL';
  String _toPart = 'FULL';
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_typeId == null || _reason.text.trim().length < 3) return setState(() => _error = 'Choose a leave type and give a reason.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final f = DateFormat('yyyy-MM-dd');
      await ref.read(apiProvider).post<Map<String, dynamic>>('/v1/mobile/leave/requests', body: {
        'leaveTypeId': _typeId,
        'fromDate': f.format(_from),
        'fromPart': _fromPart,
        'toDate': f.format(_to),
        'toPart': isSameDate(_from, _to) ? _fromPart : _toPart,
        'reason': _reason.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = ApiFailure.from(e).message;
        _busy = false;
      });
    }
  }

  static bool isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pick(bool from) async {
    final picked = await showDatePicker(context: context, initialDate: from ? _from : _to, firstDate: DateTime.now().subtract(const Duration(days: 60)), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
        if (_to.isBefore(picked)) _to = picked;
      } else {
        _to = picked.isBefore(_from) ? _from : picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(leaveBalancesProvider).valueOrNull ?? const [];
    final fmt = DateFormat('d MMM yyyy');
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Apply for leave', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _typeId,
            decoration: const InputDecoration(labelText: 'Leave type'),
            items: types.map((t) => DropdownMenuItem(value: t['leaveTypeId'] as String, child: Text('${t['name']} (${t['unlimited'] == true ? 'no limit' : '${(t['balance'] as num) - (t['pending'] as num)} left'})'))).toList(),
            onChanged: (v) => setState(() => _typeId = v),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => _pick(true), child: Text('From ${fmt.format(_from)}'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () => _pick(false), child: Text('To ${fmt.format(_to)}'))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(initialValue: _fromPart, decoration: const InputDecoration(labelText: isSameDateLabel), items: const [DropdownMenuItem(value: 'FULL', child: Text('Full day')), DropdownMenuItem(value: 'FIRST_HALF', child: Text('First half')), DropdownMenuItem(value: 'SECOND_HALF', child: Text('Second half'))], onChanged: (v) => setState(() => _fromPart = v ?? 'FULL'))),
            if (!isSameDate(_from, _to)) ...[
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String>(initialValue: _toPart, decoration: const InputDecoration(labelText: 'Last day'), items: const [DropdownMenuItem(value: 'FULL', child: Text('Full day')), DropdownMenuItem(value: 'FIRST_HALF', child: Text('First half'))], onChanged: (v) => setState(() => _toPart = v ?? 'FULL'))),
            ],
          ]),
          const SizedBox(height: 12),
          TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason'), maxLines: 2),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _submit, child: const Text('Submit request')),
        ],
      ),
    );
  }

  static const isSameDateLabel = 'First day';
}
