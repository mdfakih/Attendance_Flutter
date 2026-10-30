import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/app_lock_service.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/providers.dart';
import '../../../app/theme/theme_providers.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/gate_layout.dart';
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
    final result = await ref.read(appLockProvider).authenticateBiometric();
    if (!mounted) return;
    if (!result.ok) {
      // A cancel stays silent; a real failure (lockout, nothing enrolled) says why under the pad.
      if (result.error != null) setState(() => _error = result.error);
      return;
    }
    setState(() => _busy = true);
    await _success();
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
    // Still locked means the profile load failed (its message is shown above): drop the loader so
    // the user can retry instead of facing a stuck spinner. On success the router moves on.
    if (mounted && ref.read(sessionControllerProvider).phase == SessionPhase.locked) {
      setState(() {
        _busy = false;
        _value = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _attempts >= AppLockService.maxAttempts;
    final message = ref.watch(sessionControllerProvider.select((s) => s.message));
    final logoUrl = ref.watch(brandingProvider.select((b) => b.logoUrl));
    return GateLayout(
      logo: logoUrl == null ? null : CompanyLogo(name: '', logoUrl: logoUrl, size: 72, fallback: const AppMark(size: 64)),
      title: 'Welcome back',
      subtitle: _biometric && !locked ? 'Enter your PIN or use your fingerprint / face.' : 'Enter your PIN to continue.',
      children: [
        if (message != null) ...[GateNotice(message: message), const SizedBox(height: 16)],
        SizedBox(
          height: 400,
          child: _busy
              ? const AppLoader(label: 'Unlocking…', markSize: 48)
              : PinPad(value: _value, onChanged: locked ? (_) {} : _onChanged, onBiometric: _biometric && !locked ? _tryBiometric : null, error: _error),
        ),
        TextButton(onPressed: () => context.push<void>(Routes.pinReset), child: const Text('Forgot PIN?')),
      ],
    );
  }
}
