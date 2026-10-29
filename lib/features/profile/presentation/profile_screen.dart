import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/branding.dart';
import '../../../app/theme/theme_providers.dart';
import '../../../core/config/env.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/section_header.dart';
import 'profile_lists.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionControllerProvider).me;
    final employee = me?.employee ?? const {};
    final device = (me?.company['device'] ?? employee['device']) as Map<String, dynamic>?;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          ref.invalidate(holidaysProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _HeaderCard(
              name: me?.fullName ?? '',
              subtitle: [employee['designation'], employee['department']].whereType<String>().join(' · '),
              companyName: me?.companyName ?? '',
              logoUrl: Branding.fromJson(me?.company['branding']).logoUrl,
            ),
            const SectionHeader('Details'),
            Card(
              child: Column(children: [
                _InfoTile(icon: Icons.phone_iphone_rounded, title: 'Mobile', value: employee['phone'] as String? ?? '—'),
                _InfoTile(icon: Icons.badge_outlined, title: 'Employee code', value: employee['employeeCode'] as String? ?? '—'),
                if (employee['branch'] is String) _InfoTile(icon: Icons.apartment_rounded, title: 'Branch', value: employee['branch'] as String),
                _InfoTile(
                  icon: Icons.place_outlined,
                  title: 'Work sites',
                  value: ((employee['sites'] as List?) ?? const []).map((s) => (s as Map)['name']).join(', ').ifEmpty('None assigned'),
                ),
                if (device != null)
                  _InfoTile(
                    icon: Icons.verified_user_outlined,
                    title: 'Registered phone',
                    value: '${device['model']} · This phone is registered to you. To use another phone, ask your employer to release it.',
                    last: true,
                  ),
              ]),
            ),
            const SectionHeader('Appearance'),
            const _AppearanceCard(),
            const SectionHeader('Security'),
            Card(
              child: ListTile(
                leading: const _TileIcon(Icons.pin_outlined),
                title: const Text('Change PIN'),
                subtitle: const Text('Confirm with fingerprint, face or your current PIN'),
                trailing: const Icon(Icons.chevron_right_rounded),
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
            ),
            SectionHeader('Holidays ${DateTime.now().year}'),
            const HolidaysCard(),
            const SectionHeader('Notifications'),
            const NotificationsCard(),
            const SizedBox(height: 28),
            Column(children: [
              const AppMark(size: 32),
              const SizedBox(height: 8),
              Text('${Env.appName} · Version ${Env.appVersion}', style: text.bodySmall),
            ]),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmPin(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.lock_outline_rounded),
        title: const Text('Enter current PIN'),
        content: TextField(controller: controller, obscureText: true, keyboardType: TextInputType.number, maxLength: 6, autofocus: true, textAlign: TextAlign.center),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue'))],
      ),
    );
    if (ok != true) return false;
    return ref.read(appLockProvider).verifyPin(controller.text);
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.name, required this.subtitle, required this.companyName, this.logoUrl});

  final String name;
  final String subtitle;
  final String companyName;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: scheme.primary,
                child: Text(CompanyLogo.initials(name.isEmpty ? '?' : name), style: text.titleLarge?.copyWith(color: AppTheme.onColor(scheme.primary))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: text.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (subtitle.isNotEmpty) Text(subtitle, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                ]),
              ),
            ]),
            if (companyName.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  CompanyLogo(name: companyName, logoUrl: logoUrl, size: 32),
                  const SizedBox(width: 12),
                  Expanded(child: Text(companyName, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Theme', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('“System” follows your phone’s setting.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('System')),
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Dark')),
                ],
                selected: {mode},
                onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(11)),
      child: Icon(icon, size: 20, color: scheme.primary),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, required this.value, this.last = false});

  final IconData icon;
  final String title;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Column(children: [
        ListTile(leading: _TileIcon(icon), title: Text(title, style: Theme.of(context).textTheme.bodySmall), subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge)),
        if (!last) const Divider(indent: 70),
      ]);
}
