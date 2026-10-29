import 'package:flutter/material.dart';

/// A failed load with a clear message and a way to try again.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry, this.compact = false});

  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Message(
      compact: compact,
      icon: Icons.cloud_off_rounded,
      iconColor: scheme.error,
      title: 'Couldn’t load this',
      message: message,
      action: onRetry == null ? null : OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
    );
  }
}

/// Nothing to show yet, said kindly.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action, this.compact = false});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) =>
      _Message(compact: compact, icon: icon, iconColor: Theme.of(context).colorScheme.primary, title: title, message: message, action: action);
}

class _Message extends StatelessWidget {
  const _Message({required this.compact, required this.icon, required this.iconColor, required this.title, this.message, this.action});

  final bool compact;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: compact ? 16 : 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 48 : 64,
            height: compact ? 48 : 64,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: compact ? 24 : 30),
          ),
          SizedBox(height: compact ? 10 : 16),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
