import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/router.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/gate_layout.dart';
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
    final scheme = Theme.of(context).colorScheme;
    return GateLayout(
      title: 'Activate this phone',
      subtitle: 'Enter your mobile number and the one-time code your employer gave you.',
      children: [
        if (message != null) ...[GateNotice(message: message), const SizedBox(height: 16)],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: const InputDecoration(labelText: 'Mobile number', prefixText: '+91 ', prefixIcon: Icon(Icons.phone_iphone_rounded)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _busy ? null : _submit(),
                    decoration: InputDecoration(
                      labelText: 'Activation code',
                      hintText: 'ABCD-EFGH',
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(icon: const Icon(Icons.qr_code_scanner_rounded), tooltip: 'Scan QR', onPressed: _scan),
                    ),
                  ),
                  if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600))],
                  const SizedBox(height: 20),
                  BusyButton(label: 'Activate', icon: Icons.verified_user_rounded, busy: _busy, onPressed: _submit),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _Hint(icon: Icons.lock_outline_rounded, text: 'The code works once and links this phone to you.'),
        const _Hint(icon: Icons.qr_code_2_rounded, text: 'Got a QR code? Tap the scan icon to fill the code.'),
        const SizedBox(height: 8),
        TextButton(onPressed: () => context.go(Routes.pinReset), child: const Text('Already activated but forgot your PIN?')),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ]),
      );
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
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Scan activation QR'), backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_done) return;
              final raw = capture.barcodes.firstOrNull?.rawValue;
              if (raw != null && RegExp(r'^[A-Z2-9]{8}$').hasMatch(raw.toUpperCase())) {
                _done = true;
                Navigator.of(context).pop(raw.toUpperCase());
              }
            },
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white, width: 3)),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Text(
              'Point the camera at the QR code from your employer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
