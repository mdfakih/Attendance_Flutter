import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import 'activation_screen.dart';

/// Shown while the employer approves this phone (DEVICE_APPROVAL feature). Polls every 15 s.
class PendingApprovalScreen extends ConsumerStatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  ConsumerState<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends ConsumerState<PendingApprovalScreen> {
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _check());
    _check();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final bindingId = ref.read(sessionControllerProvider).pendingBindingId;
    if (bindingId == null) return;
    try {
      final tokens = await ref.read(activationServiceProvider).bindingStatus(bindingId);
      if (tokens == null) return;
      await ref.read(tokenManagerProvider).setTokens(accessToken: tokens['accessToken'] as String, refreshToken: tokens['refreshToken'] as String, accessExpiresAt: tokens['accessExpiresAt'] as String);
      await ref.read(secureStoreProvider).write('binding_id', bindingId);
      await ref.read(sessionControllerProvider.notifier).activated();
    } catch (e) {
      final failure = ApiFailure.from(e);
      if (failure.code == 'BINDING_INACTIVE' || failure.code == 'BAD_SIGNATURE') {
        await ref.read(sessionControllerProvider.notifier).sessionLost();
      } else if (mounted) {
        setState(() => _error = failure.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top, size: 64),
              const SizedBox(height: 16),
              Text('Waiting for approval', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Your employer needs to approve this phone before you can punch. We check automatically; you can also pull down to retry.', textAlign: TextAlign.center),
              if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
              const SizedBox(height: 24),
              OutlinedButton.icon(onPressed: _check, icon: const Icon(Icons.refresh), label: const Text('Check now')),
            ],
          ),
        ),
      ),
    );
  }
}
