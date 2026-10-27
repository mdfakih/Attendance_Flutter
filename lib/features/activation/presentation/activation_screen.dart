import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/router.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../data/activation_service.dart';

final activationServiceProvider = Provider<ActivationService>((ref) => ActivationService(
      authApi: ref.watch(authApiProvider),
      deviceKey: ref.watch(deviceKeyProvider),
      store: ref.watch(secureStoreProvider),
    ));

/// Normalises what the user types to +91XXXXXXXXXX. Returns null if it is not an Indian mobile.
String? normalizePhone(String input) {
  final digits = input.replaceAll(RegExp(r'[\s\-().]'), '');
  final match = RegExp(r'^(?:\+?91|0)?([6-9]\d{9})$').firstMatch(digits);
  return match == null ? null : '+91${match.group(1)}';
}

class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = normalizePhone(_phone.text);
    final code = _code.text.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    if (phone == null) return setState(() => _error = 'Enter your 10-digit mobile number.');
    if (code.length != 8) return setState(() => _error = 'The code has 8 characters.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await ref.read(activationServiceProvider).activate(phone: phone, code: code);
      final session = ref.read(sessionControllerProvider.notifier);
      if (outcome.isPending) {
        await session.awaitingApproval(outcome.bindingId);
      } else {
        final t = outcome.tokens!;
        await ref.read(tokenManagerProvider).setTokens(accessToken: t['accessToken'] as String, refreshToken: t['refreshToken'] as String, accessExpiresAt: t['accessExpiresAt'] as String);
        await ref.read(secureStoreProvider).write('binding_id', outcome.bindingId);
        await session.activated();
      }
    } catch (e) {
      setState(() => _error = ApiFailure.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final value = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _ScanScreen()));
    if (value != null && mounted) _code.text = value;
  }

  @override
  Widget build(BuildContext context) {
    final message = ref.watch(sessionControllerProvider.select((s) => s.message));
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            Icon(Icons.badge_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Activate this phone', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Enter your mobile number and the one-time code your employer gave you.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 32),
            if (message != null) ...[
              MaterialBanner(content: Text(message), actions: const [SizedBox.shrink()], backgroundColor: Theme.of(context).colorScheme.errorContainer),
              const SizedBox(height: 16),
            ],
            TextField(controller: _phone, keyboardType: TextInputType.phone, autofillHints: const [AutofillHints.telephoneNumber], decoration: const InputDecoration(labelText: 'Mobile number', prefixText: '+91 ')),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: 'Activation code', hintText: 'ABCD-EFGH', suffixIcon: IconButton(icon: const Icon(Icons.qr_code_scanner), tooltip: 'Scan QR', onPressed: _scan)),
            ),
            if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
            const SizedBox(height: 24),
            FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Activate')),
            const SizedBox(height: 12),
            TextButton(onPressed: () => context.go(Routes.pinReset), child: const Text('Already activated but forgot your PIN?')),
          ],
        ),
      ),
    );
  }
}

class _ScanScreen extends StatefulWidget {
  const _ScanScreen();

  @override
  State<_ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<_ScanScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan activation QR')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_done) return;
          final raw = capture.barcodes.firstOrNull?.rawValue;
          if (raw != null && RegExp(r'^[A-Z2-9]{8}$').hasMatch(raw.toUpperCase())) {
            _done = true;
            Navigator.of(context).pop(raw.toUpperCase());
          }
        },
      ),
    );
  }
}
