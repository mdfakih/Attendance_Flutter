import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/gate_layout.dart';

/// Privacy notice (DPDP): must be accepted before camera or location are used.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    final me = ref.read(sessionControllerProvider).me;
    final notice = me?.notice;
    if (notice == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final purposes = (notice['purposes'] as List).map((p) => (p as Map)['code'] as String).toList();
      await ref.read(apiProvider).post<Map<String, dynamic>>('/v1/mobile/consent', body: {'noticeId': notice['id'], 'purposes': purposes});
      await ref.read(sessionControllerProvider.notifier).refreshMe();
    } catch (e) {
      setState(() {
        _error = ApiFailure.from(e).message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionControllerProvider).me;
    final notice = me?.notice;
    final purposes = (notice?['purposes'] as List?)?.cast<Map>() ?? const [];
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (notice == null) return const Scaffold(body: AppLoader(label: 'Loading the privacy notice…'));
    return GateLayout(
      icon: Icons.privacy_tip_outlined,
      title: notice['title'] as String? ?? 'Privacy notice',
      subtitle: '${me?.companyName} uses this app to record your attendance.',
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text((notice['bodyMd'] as String? ?? '').replaceAll(RegExp(r'\*\*'), ''), style: text.bodyMedium),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What is collected', style: text.titleSmall),
                const SizedBox(height: 4),
                for (final p in purposes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Icon(Icons.check_circle_rounded, color: scheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text(p['label'] as String)),
                    ]),
                  ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[const SizedBox(height: 16), GateNotice(message: _error!)],
        const SizedBox(height: 20),
        BusyButton(label: 'I agree', icon: Icons.check_rounded, busy: _busy, onPressed: _accept),
        const SizedBox(height: 12),
        Text(
          'You can withdraw consent later from your profile; your employer will then mark attendance for you manually.',
          style: text.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
