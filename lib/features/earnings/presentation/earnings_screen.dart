import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';

final earningsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, month) async {
  final current = DateFormat('yyyy-MM').format(DateTime.now()) == month;
  return ref.watch(apiProvider).get<Map<String, dynamic>?>('/v1/mobile/earnings/${current ? 'current' : 'history'}', query: {'month': month});
});

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final key = DateFormat('yyyy-MM').format(_month);
    final data = ref.watch(earningsProvider(key));
    final isCurrent = key == DateFormat('yyyy-MM').format(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: ListView(
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
          data.when(
            loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text(ApiFailure.from(e).message),
            data: (d) => d == null
                ? const Padding(padding: EdgeInsets.all(32), child: Text('No earnings summary for this month yet. Past months appear once your employer finalises them.', textAlign: TextAlign.center))
                : Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isCurrent ? 'Earned so far' : 'Earned', style: Theme.of(context).textTheme.bodyMedium),
                          Text(_inr.format(double.parse(d['netEarned'] as String)), style: Theme.of(context).textTheme.displaySmall),
                          if (d['projectedNet'] != null) Text('Projected for the full month: ${_inr.format(double.parse(d['projectedNet'] as String))}'),
                          const Divider(height: 24),
                          _row('Payable days', '${d['payableDays']}'),
                          _row('Loss-of-pay days', '${d['lopDays']}'),
                          _row('Hours worked', '${(d['workedMinutes'] as int) ~/ 60}h ${(d['workedMinutes'] as int) % 60}m'),
                          if ((d['otMinutes'] as int) > 0) _row('Overtime', '${(d['otMinutes'] as int) ~/ 60}h ${(d['otMinutes'] as int) % 60}m'),
                          _row('Base pay', _inr.format(double.parse(d['baseEarned'] as String))),
                          if (double.parse(d['otEarned'] as String) > 0) _row('Overtime pay', _inr.format(double.parse(d['otEarned'] as String))),
                          _row('Additions', _inr.format(double.parse(d['additions'] as String))),
                          _row('Deductions', '− ${_inr.format(double.parse(d['deductions'] as String))}'),
                          const SizedBox(height: 12),
                          Text('Figures are before statutory deductions (PF, ESI, tax). ${d['status'] == 'LOCKED' ? 'Finalised by your employer.' : 'Updates as you punch.'}', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.w600))]),
      );
}
