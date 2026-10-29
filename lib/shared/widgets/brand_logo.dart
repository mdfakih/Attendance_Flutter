import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// The product mark: a ring with a tick, on the brand gradient.
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
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [scheme.primary, scheme.secondary]),
        boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.28), blurRadius: size * 0.35, offset: Offset(0, size * 0.12))],
      ),
      child: CustomPaint(painter: _MarkPainter(AppTheme.onColor(scheme.primary))),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width * 0.3);
    canvas.drawArc(rect, -math.pi / 2 + 0.55, math.pi * 2 - 1.1, false, paint);
    final w = size.width;
    final tick = Path()
      ..moveTo(w * 0.36, w * 0.51)
      ..lineTo(w * 0.47, w * 0.61)
      ..lineTo(w * 0.66, w * 0.40);
    canvas.drawPath(tick, paint);
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.color != color;
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
