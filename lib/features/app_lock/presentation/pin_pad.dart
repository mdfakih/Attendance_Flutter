import 'package:flutter/material.dart';

/// Six-digit PIN entry with dots and a numeric pad.
class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.value, required this.onChanged, this.onBiometric, this.error});

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onBiometric;
  final String? error;

  static const length = 6;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(length, (i) => Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(shape: BoxShape.circle, color: i < value.length ? scheme.primary : scheme.surfaceContainerHighest),
              )),
        ),
        SizedBox(height: 28, child: error != null ? Text(error!, style: TextStyle(color: scheme.error)) : null),
        for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['bio', '0', 'del']])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((k) => _key(context, k)).toList(),
          ),
      ],
    );
  }

  Widget _key(BuildContext context, String k) {
    Widget child;
    VoidCallback? tap;
    if (k == 'del') {
      child = const Icon(Icons.backspace_outlined);
      tap = value.isEmpty ? null : () => onChanged(value.substring(0, value.length - 1));
    } else if (k == 'bio') {
      child = onBiometric == null ? const SizedBox.shrink() : const Icon(Icons.fingerprint, size: 30);
      tap = onBiometric;
    } else {
      child = Text(k, style: Theme.of(context).textTheme.headlineSmall);
      tap = value.length >= length ? null : () => onChanged(value + k);
    }
    return SizedBox(
      width: 88,
      height: 72,
      child: TextButton(onPressed: tap, style: TextButton.styleFrom(shape: const CircleBorder()), child: child),
    );
  }
}
