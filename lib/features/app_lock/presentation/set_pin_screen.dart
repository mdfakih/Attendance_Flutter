import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../shared/widgets/gate_layout.dart';
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
    return GateLayout(
      icon: _confirming ? Icons.lock_rounded : Icons.lock_open_rounded,
      title: _confirming ? 'Confirm your PIN' : 'Create a 6-digit PIN',
      subtitle: _confirming ? 'Enter the same PIN again.' : 'You will use it to open the app on this phone.',
      children: [
        _Steps(step: _confirming ? 2 : 1),
        const SizedBox(height: 20),
        PinPad(value: _value, onChanged: _onChanged, error: _error),
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 2; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == step ? 28 : 10,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(color: i <= step ? scheme.primary : scheme.outlineVariant, borderRadius: BorderRadius.circular(3)),
          ),
      ],
    );
  }
}
