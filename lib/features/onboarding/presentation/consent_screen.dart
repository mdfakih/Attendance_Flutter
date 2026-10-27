import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(notice?['title'] as String? ?? 'Privacy notice')),
      body: notice == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('${me?.companyName} uses this app to record your attendance.', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                Text((notice['bodyMd'] as String? ?? '').replaceAll(RegExp(r'\*\*'), '')),
                const SizedBox(height: 16),
                Text('What is collected', style: Theme.of(context).textTheme.titleSmall),
                for (final p in purposes) ListTile(dense: true, leading: const Icon(Icons.check_circle_outline), title: Text(p['label'] as String)),
                if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 16),
                FilledButton(onPressed: _busy ? null : _accept, child: const Text('I agree')),
                const SizedBox(height: 8),
                const Text('You can withdraw consent later from your profile; your employer will then mark attendance for you manually.', style: TextStyle(fontSize: 12), textAlign: TextAlign.center),
              ],
            ),
    );
  }
}
