import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';

/// Where the punch is: permissions → location → work site → face check → upload.
class PunchProgress extends StatelessWidget {
  const PunchProgress({super.key, required this.step, required this.status});

  final int step;
  final String status;

  static const _steps = [
    (Icons.verified_user_outlined, 'Permissions'),
    (Icons.my_location_rounded, 'Your location'),
    (Icons.place_outlined, 'Work site check'),
    (Icons.face_retouching_natural_rounded, 'Face check'),
    (Icons.cloud_upload_outlined, 'Saving your punch'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final current = step.clamp(0, _steps.length - 1);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(alignment: Alignment.center, children: [
                  const SizedBox.expand(child: CircularProgressIndicator(strokeWidth: 4)),
                  Icon(_steps[current].$1, size: 38, color: scheme.primary),
                ]),
              ),
              const SizedBox(height: 20),
              Text(status, style: text.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      for (var i = 0; i < _steps.length; i++)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            i < current ? Icons.check_circle_rounded : (i == current ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded),
                            color: i < current ? AppPalette.of(context).success : (i == current ? scheme.primary : scheme.outline),
                          ),
                          title: Text(
                            _steps[i].$2,
                            style: text.bodyMedium?.copyWith(
                              fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                              color: i > current ? scheme.onSurfaceVariant : scheme.onSurface,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Oval guide for placing the face, dimming the area around it.
class FaceGuidePainter extends CustomPainter {
  FaceGuidePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final oval = Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.45), width: size.width * 0.68, height: size.height * 0.62);
    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(oval);
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.35));
    canvas.drawOval(oval, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(FaceGuidePainter oldDelegate) => oldDelegate.color != color;
}
