import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/gate_layout.dart';
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
    return GateLayout(
      appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
      icon: Icons.password_rounded,
      title: 'Reset PIN',
      subtitle: 'Ask your employer for a PIN reset code. It only works on the phone that is already registered to you.',
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Mobile number', prefixText: '+91 ', prefixIcon: Icon(Icons.phone_iphone_rounded)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Reset code', hintText: 'ABCD-EFGH', prefixIcon: Icon(Icons.key_rounded)),
                ),
                if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600))],
                const SizedBox(height: 20),
                BusyButton(label: 'Continue', icon: Icons.arrow_forward_rounded, busy: _busy, onPressed: _submit),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
