import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/states.dart';

final notificationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async => (await ref.watch(apiProvider).get<List<dynamic>>('/v1/mobile/notifications')).cast<Map<String, dynamic>>(),
);
final holidaysProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async => (await ref.watch(apiProvider).get<List<dynamic>>('/v1/mobile/holidays', query: {'year': DateTime.now().year})).cast<Map<String, dynamic>>(),
);

class HolidaysCard extends ConsumerWidget {
  const HolidaysCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holidays = ref.watch(holidaysProvider);
    return Card(
      child: holidays.when(
        loading: () => const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: SkeletonList(count: 3)),
        error: (e, _) => ErrorState(message: ApiFailure.from(e).message, onRetry: () => ref.invalidate(holidaysProvider), compact: true),
        data: (rows) => rows.isEmpty
            ? const EmptyState(icon: Icons.celebration_outlined, title: 'No holidays listed', compact: true)
            : Column(children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(indent: 76),
                  _HolidayTile(holiday: rows[i]),
                ],
              ]),
      ),
    );
  }
}

class _HolidayTile extends StatelessWidget {
  const _HolidayTile({required this.holiday});

  final Map<String, dynamic> holiday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final date = DateTime.parse(holiday['date'] as String);
    final past = date.isBefore(DateTime.now().subtract(const Duration(days: 1)));
    return Opacity(
      opacity: past ? 0.55 : 1,
      child: ListTile(
        leading: Container(
          width: 44,
          height: 48,
          decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(DateFormat('d').format(date), style: text.titleMedium?.copyWith(color: scheme.primary, height: 1.1)),
            Text(DateFormat('MMM').format(date).toUpperCase(), style: text.labelSmall?.copyWith(color: scheme.primary, height: 1.1)),
          ]),
        ),
        title: Text(holiday['name'] as String),
        subtitle: Text(DateFormat('EEEE').format(date)),
      ),
    );
  }
}

class NotificationsCard extends ConsumerWidget {
  const NotificationsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final extraTime = ref.watch(sessionControllerProvider.select((s) => s.me?.extraTimeEnabled ?? true));
    return Card(
      child: notifications.when(
        loading: () => const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: SkeletonList(count: 3)),
        error: (e, _) => ErrorState(message: ApiFailure.from(e).message, onRetry: () => ref.invalidate(notificationsProvider), compact: true),
        data: (rows) => rows.isEmpty
            ? const EmptyState(icon: Icons.notifications_none_rounded, title: 'You’re all caught up', compact: true)
            : Column(children: [
                for (final (i, n) in rows.take(20).indexed) ...[
                  if (i > 0) const Divider(indent: 16),
                  _NotificationTile(notification: n, extraTime: extraTime),
                ],
              ]),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.extraTime});

  final Map<String, dynamic> notification;
  final bool extraTime;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final scheme = Theme.of(context).colorScheme;
    final route = notificationRoute({...?(n['data'] as Map?)?.cast<String, dynamic>(), 'type': n['type']}, extraTime: extraTime);
    final unread = n['readAt'] == null;
    return ListTile(
      leading: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(width: 8, height: 8, decoration: BoxDecoration(color: unread ? scheme.primary : Colors.transparent, shape: BoxShape.circle)),
      ),
      minLeadingWidth: 8,
      title: Text(n['title'] as String, style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w500)),
      subtitle: Text(n['body'] as String),
      trailing: Text(DateFormat('d MMM').format(DateTime.parse(n['createdAt'] as String).toLocal()), style: Theme.of(context).textTheme.bodySmall),
      onTap: route == null ? null : () => context.push<void>(route),
    );
  }
}
