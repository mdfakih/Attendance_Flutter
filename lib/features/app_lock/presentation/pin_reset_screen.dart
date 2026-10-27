import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../../../core/storage/secure_storage.dart';
import '../../activation/presentation/activation_screen.dart';

/// Forgot PIN: the employer issues a PIN-reset code; the request is signed by this phone's key.
class PinResetScreen extends ConsumerStatefulWidget {
  const PinResetScreen({super.key});

  @override
  ConsumerState<PinResetScreen> createState() => _PinResetScreenState();
}

class _PinResetScreenState extends ConsumerState<PinResetScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(secureStoreProvider).read(SecureKeys.phone).then((p) {
      if (p != null && mounted) _phone.text = p.replaceFirst('+91', '');
    });
  }

  Future<void> _submit() async {
    final phone = normalizePhone(_phone.text);
    final code = _code.text.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    if (phone == null || code.length != 8) return setState(() => _error = 'Enter your mobile number and the 8-character reset code.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tokens = await ref.read(activationServiceProvider).pinReset(phone: phone, code: code);
      await ref.read(tokenManagerProvider).setTokens(accessToken: tokens['accessToken'] as String, refreshToken: tokens['refreshToken'] as String, accessExpiresAt: tokens['accessExpiresAt'] as String);
      await ref.read(appLockProvider).clearPin();
      await ref.read(sessionControllerProvider.notifier).activated();
    } catch (e) {
      setState(() => _error = ApiFailure.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset PIN'), leading: BackButton(onPressed: () => context.pop())),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Ask your employer for a PIN reset code. It only works on the phone that is already registered to you.'),
          const SizedBox(height: 24),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile number', prefixText: '+91 ')),
          const SizedBox(height: 16),
          TextField(controller: _code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Reset code', hintText: 'ABCD-EFGH')),
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
          const SizedBox(height: 24),
          FilledButton(onPressed: _busy ? null : _submit, child: const Text('Continue')),
        ],
      ),
    );
  }
}
