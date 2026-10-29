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
          children: List.generate(length, (i) {
            final filled = i < value.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: filled ? 16 : 14,
              height: filled ? 16 : 14,
              margin: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? (error != null ? scheme.error : scheme.primary) : Colors.transparent,
                border: Border.all(color: filled ? Colors.transparent : scheme.outline, width: 2),
              ),
            );
          }),
        ),
        SizedBox(
          height: 40,
          child: Center(child: error != null ? Text(error!, textAlign: TextAlign.center, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)) : null),
        ),
        for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['bio', '0', 'del']])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((k) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: _key(context, k))).toList(),
            ),
          ),
      ],
    );
  }

  Widget _key(BuildContext context, String k) {
    final scheme = Theme.of(context).colorScheme;
    Widget child;
    VoidCallback? tap;
    var plain = false;
    if (k == 'del') {
      child = const Icon(Icons.backspace_outlined);
      tap = value.isEmpty ? null : () => onChanged(value.substring(0, value.length - 1));
      plain = true;
    } else if (k == 'bio') {
      child = onBiometric == null ? const SizedBox.shrink() : Icon(Icons.fingerprint_rounded, size: 32, color: scheme.primary);
      tap = onBiometric;
      plain = true;
    } else {
      child = Text(k, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600));
      tap = value.length >= length ? null : () => onChanged(value + k);
    }
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: plain ? Colors.transparent : scheme.surfaceContainer,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: tap,
          child: Center(child: IconTheme.merge(data: IconThemeData(color: scheme.onSurface), child: DefaultTextStyle.merge(style: TextStyle(color: scheme.onSurface), child: child))),
        ),
      ),
    );
  }
}
