import 'package:flutter/material.dart';

import 'brand_logo.dart';

/// Centered, scrollable layout for the screens before the app opens (activation, PIN, approval).
class GateLayout extends StatelessWidget {
  const GateLayout({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.logo,
    this.appBar,
    required this.children,
  });

  final String title;
  final String? subtitle;

  /// Shown in a tinted circle instead of the product mark.
  final IconData? icon;

  /// Replaces the product mark (e.g. the company logo).
  final Widget? logo;
  final PreferredSizeWidget? appBar;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: logo ?? (icon != null ? _IconBadge(icon: icon!) : const AppMark(size: 64))),
                  if (logo == null && icon == null) ...[
                    const SizedBox(height: 10),
                    Center(child: BrandWordmark(style: text.titleMedium)),
                  ],
                  const SizedBox(height: 20),
                  Text(title, textAlign: TextAlign.center, style: text.headlineSmall),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(subtitle!, textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 28),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Icon(icon, size: 36, color: scheme.primary),
    );
  }
}

/// A tinted message box (error by default) for gate screens.
class GateNotice extends StatelessWidget {
  const GateNotice({super.key, required this.message, this.error = true});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = error ? scheme.error : scheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(error ? Icons.error_outline_rounded : Icons.info_outline_rounded, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: error ? scheme.error : scheme.onSurface))),
      ]),
    );
  }
}
