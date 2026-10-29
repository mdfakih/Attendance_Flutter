import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router.dart';
import '../../../core/config/env.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';

final notificationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async => (await ref.watch(apiProvider).get<List<dynamic>>('/v1/mobile/notifications')).cast<Map<String, dynamic>>(),
);
final holidaysProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async => (await ref.watch(apiProvider).get<List<dynamic>>('/v1/mobile/holidays', query: {'year': DateTime.now().year})).cast<Map<String, dynamic>>(),
);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionControllerProvider).me;
    final employee = me?.employee ?? const {};
    final device = (me?.company['device'] ?? employee['device']) as Map<String, dynamic>?;
    final notifications = ref.watch(notificationsProvider);
    final holidays = ref.watch(holidaysProvider);
    final fmt = DateFormat('d MMM');
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(child: Text((me?.fullName ?? '?').substring(0, 1))),
            title: Text(me?.fullName ?? ''),
            subtitle: Text([employee['designation'], employee['branch'], employee['department']].whereType<String>().join(' · ')),
          ),
          ListTile(leading: const Icon(Icons.phone_android), title: const Text('Mobile'), subtitle: Text(employee['phone'] as String? ?? '')),
          ListTile(leading: const Icon(Icons.badge_outlined), title: const Text('Employee code'), subtitle: Text(employee['employeeCode'] as String? ?? '—')),
          ListTile(leading: const Icon(Icons.place_outlined), title: const Text('Work sites'), subtitle: Text(((employee['sites'] as List?) ?? const []).map((s) => (s as Map)['name']).join(', '))),
          if (device != null) ListTile(leading: const Icon(Icons.security), title: const Text('Registered phone'), subtitle: Text('${device['model']} · This phone is registered to you. To use another phone, ask your employer to release it.')),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: const Text('Change PIN'),
            onTap: () async {
              final lock = ref.read(appLockProvider);
              var ok = await lock.authenticateBiometric();
              if (!ok && context.mounted) ok = await _confirmPin(context, ref);
              if (ok) {
                await lock.clearPin();
                await ref.read(sessionControllerProvider.notifier).bootstrap();
              }
            },
          ),
          const Divider(),
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text('Holidays ${DateTime.now().year}', style: Theme.of(context).textTheme.titleSmall)),
          holidays.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ListTile(title: Text(ApiFailure.from(e).message)),
            data: (rows) => rows.isEmpty
                ? const ListTile(title: Text('No holidays listed.'))
                : Column(children: rows.map((h) => ListTile(dense: true, leading: Text(fmt.format(DateTime.parse(h['date'] as String))), title: Text(h['name'] as String))).toList()),
          ),
          const Divider(),
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text('Notifications', style: Theme.of(context).textTheme.titleSmall)),
          notifications.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ListTile(title: Text(ApiFailure.from(e).message)),
            data: (rows) => rows.isEmpty
                ? const ListTile(title: Text('Nothing yet.'))
                : Column(
                    children: rows.take(20).map((n) {
                      final route = notificationRoute({...?(n['data'] as Map?)?.cast<String, dynamic>(), 'type': n['type']});
                      return ListTile(
                        dense: true,
                        title: Text(n['title'] as String),
                        subtitle: Text(n['body'] as String),
                        trailing: Text(fmt.format(DateTime.parse(n['createdAt'] as String).toLocal())),
                        onTap: route == null ? null : () => context.push<void>(route),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 16),
          Center(child: Text('Version ${Env.appVersion}', style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<bool> _confirmPin(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter current PIN'),
        content: TextField(controller: controller, obscureText: true, keyboardType: TextInputType.number, maxLength: 6, autofocus: true),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue'))],
      ),
    );
    if (ok != true) return false;
    return ref.read(appLockProvider).verifyPin(controller.text);
  }
}
