import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_palette.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/status_pill.dart';
import 'apply_leave_sheet.dart';

final leaveBalancesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async => (await ref.watch(apiProvider).get<List<dynamic>>('/v1/mobile/leave/balances')).cast<Map<String, dynamic>>(),
);
final leaveRequestsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async => (await ref.watch(apiProvider).get<List<dynamic>>('/v1/mobile/leave/requests')).cast<Map<String, dynamic>>(),
);

class LeaveScreen extends ConsumerWidget {
  const LeaveScreen({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(leaveBalancesProvider);
    ref.invalidate(leaveRequestsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(leaveBalancesProvider);
    final requests = ref.watch(leaveRequestsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Leave')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final applied = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => const ApplyLeaveSheet());
          if (applied == true) _refresh(ref);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Apply for leave'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            const SectionHeader('Balances', padding: EdgeInsets.fromLTRB(4, 4, 4, 10)),
            balances.when(
              loading: () => const Shimmer(child: Row(children: [SkeletonBox(width: 140, height: 104, radius: 18), SizedBox(width: 12), SkeletonBox(width: 140, height: 104, radius: 18)])),
              error: (e, _) => Card(child: ErrorState(message: ApiFailure.from(e).message, onRetry: () => ref.invalidate(leaveBalancesProvider), compact: true)),
              data: (rows) => rows.isEmpty
                  ? const Card(child: EmptyState(icon: Icons.beach_access_rounded, title: 'No leave types yet', message: 'Your employer has not set up leave.', compact: true))
                  : SizedBox(
                      height: 112,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => _BalanceCard(balance: rows[i]),
                      ),
                    ),
            ),
            const SectionHeader('My requests'),
            requests.when(
              loading: () => const Column(children: [SkeletonCard(lines: 2), SizedBox(height: 12), SkeletonCard(lines: 2)]),
              error: (e, _) => Card(child: ErrorState(message: ApiFailure.from(e).message, onRetry: () => ref.invalidate(leaveRequestsProvider), compact: true)),
              data: (rows) => rows.isEmpty
                  ? const Card(
                      child: EmptyState(icon: Icons.event_note_rounded, title: 'No leave requests yet', message: 'Tap “Apply for leave” to send your first request.'),
                    )
                  : Column(children: rows.map((r) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _RequestCard(request: r))).toList()),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final Map<String, dynamic> balance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final unlimited = balance['unlimited'] == true;
    final pending = balance['pending'] as num? ?? 0;
    final left = unlimited ? '∞' : '${(balance['balance'] as num) - pending}';
    return SizedBox(
      width: 140,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(balance['name'] as String, style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              const Spacer(),
              Text(left, style: text.headlineMedium?.copyWith(color: scheme.primary)),
              Text(unlimited ? 'no limit' : (pending > 0 ? 'days left · $pending pending' : 'days left'), style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    final fmt = DateFormat('d MMM');
    final r = request;
    final status = r['status'] as String;
    final color = switch (status) { 'APPROVED' => palette.success, 'PENDING' => palette.warning, 'REJECTED' => scheme.error, _ => palette.neutral };
    final dates = '${fmt.format(DateTime.parse(r['fromDate'] as String))}${r['toDate'] != r['fromDate'] ? ' → ${fmt.format(DateTime.parse(r['toDate'] as String))}' : ''}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('${(r['leaveType'] as Map?)?['name']} · ${r['days']} day(s)', style: text.titleSmall)),
              StatusPill(label: _statusLabel(status), color: color),
              const SizedBox(width: 8),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.event_rounded, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(dates, style: text.bodyMedium),
            ]),
            if ((r['reason'] as String?)?.isNotEmpty ?? false)
              Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: Text(r['reason'] as String, style: text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
            if (status == 'PENDING' || status == 'APPROVED')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    try {
                      await ref.read(apiProvider).post<Map<String, dynamic>>('/v1/mobile/leave/requests/${r['id']}/cancel');
                      ref.invalidate(leaveRequestsProvider);
                      ref.invalidate(leaveBalancesProvider);
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiFailure.from(e).message)));
                    }
                  },
                  child: const Text('Cancel request'),
                ),
              )
            else
              const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(String status) => switch (status) {
        'PENDING' => 'Pending',
        'APPROVED' => 'Approved',
        'REJECTED' => 'Rejected',
        'CANCELLED' => 'Cancelled',
        _ => status,
      };
}
