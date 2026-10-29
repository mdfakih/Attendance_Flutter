import 'package:flutter/material.dart';

import '../../core/config/env.dart';
import 'brand_logo.dart';

/// Branded loading indicator: a gently pulsing mark, a label and a slim progress bar.
class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.label, this.markSize = 56});

  final String? label;
  final double markSize;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Pulse(child: AppMark(size: markSize)),
          const SizedBox(height: 20),
          if (label != null) ...[
            Text(label!, style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
            const SizedBox(height: 14),
          ],
          const SizedBox(width: 120, child: ClipRRect(borderRadius: BorderRadius.all(Radius.circular(4)), child: LinearProgressIndicator(minHeight: 4))),
        ],
      ),
    );
  }
}

/// First screen while the session is restored.
class BrandedSplash extends StatelessWidget {
  const BrandedSplash({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.35),
            radius: 1.1,
            colors: [scheme.primary.withValues(alpha: 0.16), Theme.of(context).scaffoldBackgroundColor],
          ),
        ),
        child: SafeArea(
          child: SizedBox.expand(
            child: Column(
              children: [
                const Spacer(flex: 3),
                const _Pulse(child: AppMark(size: 84)),
                const SizedBox(height: 24),
                Text(Env.appName, style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(Env.tagline, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const Spacer(flex: 2),
                const SizedBox(width: 140, child: ClipRRect(borderRadius: BorderRadius.all(Radius.circular(4)), child: LinearProgressIndicator(minHeight: 4))),
                const SizedBox(height: 12),
                Text('Getting things ready…', style: text.bodySmall),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  late final Animation<double> _scale = Tween<double>(begin: 0.92, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _scale, child: widget.child);
}
