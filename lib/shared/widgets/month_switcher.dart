import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// "‹ October 2026 ›"; the next arrow is disabled on the current month.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key, required this.month, required this.onChanged});

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrent = month.year == now.year && month.month == now.month;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outlineVariant)),
      child: Row(
        children: [
          IconButton(tooltip: 'Previous month', onPressed: () => onChanged(DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(child: Text(DateFormat('MMMM yyyy').format(month), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium)),
          IconButton(tooltip: 'Next month', onPressed: isCurrent ? null : () => onChanged(DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right_rounded)),
        ],
      ),
    );
  }
}
