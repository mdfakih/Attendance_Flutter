import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/config/env.dart';

/// The product mark: a "K" whose upper arm is a rising arrow (kamai, going up), on the brand gradient.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 13 / 48),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [scheme.primary, scheme.secondary]),
        boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.28), blurRadius: size * 0.35, offset: Offset(0, size * 0.12))],
      ),
      child: CustomPaint(painter: _MarkPainter(AppTheme.onColor(scheme.primary))),
    );
  }
}

/// Same geometry as the web icon and the launcher icons: a 48-unit grid, 4.4-unit round strokes.
class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color);

  final Color color;

  static final _glyph = Path()
    ..moveTo(15.5, 12.5)
    ..lineTo(15.5, 35.5) // stem
    ..moveTo(15.5, 29.5)
    ..lineTo(32.5, 12.5) // rising arm
    ..moveTo(24.5, 12.5)
    ..lineTo(32.5, 12.5)
    ..lineTo(32.5, 20.5) // arrowhead
    ..moveTo(22.5, 22.5)
    ..lineTo(32.5, 35.5); // leg

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..save()
      ..scale(size.width / 48)
      ..drawPath(_glyph, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.color != color;
}

/// The product name as a wordmark: "Kamai" in the text colour, "Go" in the brand colour.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.style, this.accentColor});

  final TextStyle? style;

  /// Defaults to the brand primary.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final base = (style ?? Theme.of(context).textTheme.titleLarge)?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3);
    return Text.rich(
      TextSpan(
        text: Env.appNameBase,
        children: [TextSpan(text: Env.appNameAccent, style: TextStyle(color: accentColor ?? Theme.of(context).colorScheme.primary))],
      ),
      style: base,
      semanticsLabel: Env.appName,
    );
  }
}

/// The company's logo, or its initials on the brand colour when there is no logo or it fails to load.
class CompanyLogo extends StatelessWidget {
  const CompanyLogo({super.key, required this.name, this.logoUrl, this.size = 44, this.fallback});

  final String name;
  final String? logoUrl;
  final double size;

  /// Shown instead of the initials when there is no logo or it fails to load.
  final Widget? fallback;

  static String initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    final letters = words.length == 1 ? words.first.substring(0, math.min(2, words.first.length)) : '${words[0][0]}${words[1][0]}';
    return letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.28);
    final fallback = this.fallback ?? _Initials(text: initials(name), size: size, radius: radius);
    final url = logoUrl;
    if (url == null) return fallback;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Colors.white, borderRadius: radius, border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.contain,
          frameBuilder: (_, child, _, _) => Padding(padding: EdgeInsets.all(size * 0.08), child: child),
          errorBuilder: (_, _, _) => fallback,
          loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.text, required this.size, required this.radius});

  final String text;
  final double size;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [scheme.primary, scheme.secondary]),
      ),
      child: Text(
        text,
        style: TextStyle(color: AppTheme.onColor(scheme.primary), fontWeight: FontWeight.w800, fontSize: size * 0.36, letterSpacing: 0.5),
      ),
    );
  }
}
