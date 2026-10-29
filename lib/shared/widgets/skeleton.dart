import 'package:flutter/material.dart';

/// Sweeps a soft highlight across its [SkeletonBox] children while content loads.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHigh;
    final highlight = Color.lerp(base, scheme.surface, 0.7)!;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          colors: [base, highlight, base],
          stops: const [0.25, 0.5, 0.75],
          begin: const Alignment(-1, -0.3),
          end: const Alignment(1, 0.3),
          transform: _Slide(_controller.value),
        ).createShader(bounds),
        child: child,
      ),
    );
  }
}

class _Slide extends GradientTransform {
  const _Slide(this.t);

  final double t;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) => Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}

/// A grey placeholder block; wrap a group of them in [Shimmer].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 10});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(radius)),
      );
}

/// Placeholder for a card of text lines.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 3, this.height});

  final int lines;
  final double? height;

  @override
  Widget build(BuildContext context) => Card(
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Shimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(width: 140, height: 16),
                  for (var i = 0; i < lines; i++) ...[
                    const SizedBox(height: 12),
                    SkeletonBox(width: i.isEven ? double.infinity : 200, height: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}

/// Placeholder for a list of rows (avatar + two lines).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) => Shimmer(
        child: Column(
          children: [
            for (var i = 0; i < count; i++)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  SkeletonBox(width: 40, height: 40, radius: 12),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SkeletonBox(width: double.infinity, height: 12),
                      SizedBox(height: 8),
                      SkeletonBox(width: 120, height: 10),
                    ]),
                  ),
                ]),
              ),
          ],
        ),
      );
}
