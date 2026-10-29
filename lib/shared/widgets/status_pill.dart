import 'package:flutter/material.dart';

/// A small rounded label tinted with [color], e.g. a day's status.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, this.icon, this.onDark = false});

  final String label;
  final Color color;
  final IconData? icon;

  /// On a coloured (hero) background: white text on a translucent white pill.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : color;
    final bg = onDark ? Colors.white.withValues(alpha: 0.18) : color.withValues(alpha: 0.13);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 5)] else ...[
            Container(width: 7, height: 7, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
