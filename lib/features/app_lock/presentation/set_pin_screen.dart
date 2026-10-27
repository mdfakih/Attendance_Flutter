import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'pin_pad.dart';

class SetPinScreen extends ConsumerStatefulWidget {
  const SetPinScreen({super.key});

  @override
  ConsumerState<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends ConsumerState<SetPinScreen> {
  String _first = '';
  String _value = '';
  String? _error;
  bool _confirming = false;

  Future<void> _onChanged(String v) async {
    setState(() {
      _value = v;
      _error = null;
    });
    if (v.length < PinPad.length) return;
    if (!_confirming) {
      setState(() {
        _first = v;
        _value = '';
        _confirming = true;
      });
      return;
    }
    if (v != _first) {
      setState(() {
        _error = 'PINs do not match. Start again.';
        _value = '';
        _first = '';
        _confirming = false;
      });
      return;
    }
    final lock = ref.read(appLockProvider);
    await lock.setPin(v);
    if (await lock.canUseBiometrics() && mounted) {
      final enable = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Use fingerprint / face unlock?'),
          content: const Text('You can unlock the app with your phone\'s biometrics instead of the PIN.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enable'))],
        ),
      );
      await lock.setBiometricEnabled(enable ?? false);
    }
    await ref.read(sessionControllerProvider.notifier).pinSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Text(_confirming ? 'Confirm your PIN' : 'Create a 6-digit PIN', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 32), child: Text('You will use it to open the app on this phone.', textAlign: TextAlign.center)),
            const SizedBox(height: 32),
            PinPad(value: _value, onChanged: _onChanged, error: _error),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
