import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_palette.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/month_switcher.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/status_pill.dart';

final earningsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, month) async {
  final current = DateFormat('yyyy-MM').format(DateTime.now()) == month;
  return ref.watch(apiProvider).get<Map<String, dynamic>?>('/v1/mobile/earnings/${current ? 'current' : 'history'}', query: {'month': month});
});

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

String _money(Object? value) => _inr.format(double.parse(value as String));
String _hours(int minutes) => '${minutes ~/ 60}h ${minutes % 60}m';

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
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(earningsProvider(key)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            MonthSwitcher(month: _month, onChanged: (m) => setState(() => _month = m)),
            const SizedBox(height: 16),
            data.when(
              loading: () => const Shimmer(child: Column(children: [SkeletonBox(height: 150, radius: 24), SizedBox(height: 16), SkeletonBox(height: 260, radius: 18)])),
              error: (e, _) => Card(child: ErrorState(message: ApiFailure.from(e).message, onRetry: () => ref.invalidate(earningsProvider(key)))),
              data: (d) => d == null
                  ? const Card(
                      child: EmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'No summary yet',
                        message: 'No earnings summary for this month yet. Past months appear once your employer finalises them.',
                      ),
                    )
                  : _Summary(data: d, isCurrent: isCurrent),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.data, required this.isCurrent});

  final Map<String, dynamic> data;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final locked = d['status'] == 'LOCKED';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: palette.heroGradient, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(isCurrent ? 'Earned so far' : 'Earned', style: text.titleSmall?.copyWith(color: palette.onHero.withValues(alpha: 0.9))),
                const Spacer(),
                StatusPill(label: locked ? 'Finalised' : 'Live', color: palette.onHero, onDark: true, icon: locked ? Icons.lock_rounded : Icons.bolt_rounded),
              ]),
              const SizedBox(height: 8),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(_money(d['netEarned']), style: text.displaySmall?.copyWith(color: palette.onHero))),
              if (d['projectedNet'] != null) ...[
                const SizedBox(height: 4),
                Text('Projected for the full month: ${_money(d['projectedNet'])}', style: text.bodyMedium?.copyWith(color: palette.onHero.withValues(alpha: 0.88))),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
            child: Column(
              children: [
                _Row('Payable days', '${d['payableDays']}'),
                _Row('Loss-of-pay days', '${d['lopDays']}'),
                _Row('Hours worked', _hours(d['workedMinutes'] as int)),
                if ((d['otMinutes'] as int) > 0) _Row('Overtime', _hours(d['otMinutes'] as int)),
                const Divider(height: 20),
                _Row('Base pay', _money(d['baseEarned'])),
                if (double.parse(d['otEarned'] as String) > 0) _Row('Overtime pay', _money(d['otEarned'])),
                _Row('Additions', _money(d['additions'])),
                _Row('Deductions', '− ${_money(d['deductions'])}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Figures are before statutory deductions (PF, ESI, tax). ${locked ? 'Finalised by your employer.' : 'Updates as you punch.'}',
            style: text.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ]),
      );
}
