import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/app_lock_service.dart';
import '../../../core/providers.dart';
import 'pin_pad.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  String _value = '';
  String? _error;
  int _attempts = 0;
  bool _biometric = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(appLockProvider).biometricEnabled().then((enabled) async {
      if (!mounted) return;
      setState(() => _biometric = enabled);
      if (enabled) _tryBiometric();
    });
  }

  Future<void> _tryBiometric() async {
    if (await ref.read(appLockProvider).authenticateBiometric()) await _success();
  }

  Future<void> _onChanged(String v) async {
    setState(() {
      _value = v;
      _error = null;
    });
    if (v.length < PinPad.length) return;
    setState(() => _busy = true);
    final ok = await ref.read(appLockProvider).verifyPin(v);
    if (ok) return _success();
    _attempts += 1;
    if (!mounted) return;
    setState(() {
      _busy = false;
      _value = '';
      _error = _attempts >= AppLockService.maxAttempts ? 'Too many attempts. Reset your PIN with a code from your employer.' : 'Wrong PIN (${AppLockService.maxAttempts - _attempts} left)';
    });
  }

  Future<void> _success() async {
    await ref.read(sessionControllerProvider.notifier).unlocked();
  }

  @override
  Widget build(BuildContext context) {
    final locked = _attempts >= AppLockService.maxAttempts;
    final message = ref.watch(sessionControllerProvider.select((s) => s.message));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(Icons.lock_outline, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text('Enter your PIN', style: Theme.of(context).textTheme.headlineSmall),
            if (message != null) Padding(padding: const EdgeInsets.all(16), child: Text(message, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: 24),
            if (_busy) const CircularProgressIndicator() else PinPad(value: _value, onChanged: locked ? (_) {} : _onChanged, onBiometric: _biometric && !locked ? _tryBiometric : null, error: _error),
            const Spacer(),
            TextButton(onPressed: () => context.go(Routes.pinReset), child: const Text('Forgot PIN?')),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
