import 'package:flutter/material.dart';

/// Primary action that shows a spinner while its work runs and ignores taps meanwhile.
class BusyButton extends StatelessWidget {
  const BusyButton({super.key, required this.label, required this.onPressed, this.busy = false, this.icon, this.tonal = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spinnerColor = tonal ? scheme.onSecondaryContainer : scheme.onPrimary;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy)
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: spinnerColor))
        else if (icon != null)
          Icon(icon, size: 20),
        if (busy || icon != null) const SizedBox(width: 10),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
    final tap = onPressed == null ? null : (busy ? () {} : onPressed);
    return tonal ? FilledButton.tonal(onPressed: tap, child: child) : FilledButton(onPressed: tap, child: child);
  }
}
