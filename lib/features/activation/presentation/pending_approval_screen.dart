import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/gate_layout.dart';
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
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final bindingId = ref.read(sessionControllerProvider).pendingBindingId;
    if (bindingId == null || _checking) return;
    if (mounted) setState(() => _checking = true);
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
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GateLayout(
      icon: Icons.hourglass_top_rounded,
      title: 'Waiting for approval',
      subtitle: 'Your employer needs to approve this phone before you can punch. We check automatically every few seconds.',
      children: [
        if (_error != null) ...[GateNotice(message: _error!), const SizedBox(height: 16)],
        const GateNotice(message: 'You can close the app. Approval is kept, and the app opens normally once it is approved.', error: false),
        const SizedBox(height: 20),
        BusyButton(label: _checking ? 'Checking…' : 'Check now', icon: Icons.refresh_rounded, busy: _checking, tonal: true, onPressed: _check),
      ],
    );
  }
}
