import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/busy_button.dart';
import 'leave_screen.dart';

/// Leave request form. Pops `true` once the request is sent.
class ApplyLeaveSheet extends ConsumerStatefulWidget {
  const ApplyLeaveSheet({super.key});

  @override
  ConsumerState<ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends ConsumerState<ApplyLeaveSheet> {
  String? _typeId;
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  String _fromPart = 'FULL';
  String _toPart = 'FULL';
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

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
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Apply for leave', style: text.titleLarge),
            const SizedBox(height: 4),
            Text('Your employer is notified and approves it.', style: text.bodySmall),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _typeId,
              decoration: const InputDecoration(labelText: 'Leave type', prefixIcon: Icon(Icons.category_outlined)),
              items: types
                  .map((t) => DropdownMenuItem(
                        value: t['leaveTypeId'] as String,
                        child: Text('${t['name']} (${t['unlimited'] == true ? 'no limit' : '${(t['balance'] as num) - (t['pending'] as num)} left'})'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _typeId = v),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _DateButton(label: 'From', value: fmt.format(_from), onTap: () => _pick(true))),
              const SizedBox(width: 10),
              Expanded(child: _DateButton(label: 'To', value: fmt.format(_to), onTap: () => _pick(false))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _fromPart,
                  decoration: const InputDecoration(labelText: isSameDateLabel),
                  items: const [
                    DropdownMenuItem(value: 'FULL', child: Text('Full day')),
                    DropdownMenuItem(value: 'FIRST_HALF', child: Text('First half')),
                    DropdownMenuItem(value: 'SECOND_HALF', child: Text('Second half')),
                  ],
                  onChanged: (v) => setState(() => _fromPart = v ?? 'FULL'),
                ),
              ),
              if (!isSameDate(_from, _to)) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _toPart,
                    decoration: const InputDecoration(labelText: 'Last day'),
                    items: const [DropdownMenuItem(value: 'FULL', child: Text('Full day')), DropdownMenuItem(value: 'FIRST_HALF', child: Text('First half'))],
                    onChanged: (v) => setState(() => _toPart = v ?? 'FULL'),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 12),
            TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason'), maxLines: 2, textCapitalization: TextCapitalization.sentences),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: 20),
            BusyButton(label: 'Submit request', icon: Icons.send_rounded, busy: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }

  static const isSameDateLabel = 'First day';
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: scheme.outlineVariant), color: scheme.surfaceContainerLow),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              Text(value, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      ),
    );
  }
}
