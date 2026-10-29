import 'package:flutter/material.dart';

/// Semantic colours (status, hero gradient) that Material's ColorScheme does not carry.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.success,
    required this.warning,
    required this.info,
    required this.leave,
    required this.neutral,
    required this.heroStart,
    required this.heroEnd,
    required this.onHero,
  });

  final Color success;
  final Color warning;
  final Color info;
  final Color leave;
  final Color neutral;
  final Color heroStart;
  final Color heroEnd;
  final Color onHero;

  static const _light = AppPalette(
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    info: Color(0xFF1D4ED8),
    leave: Color(0xFF7C3AED),
    neutral: Color(0xFF64748B),
    heroStart: Color(0xFF4F46E5),
    heroEnd: Color(0xFF0EA5E9),
    onHero: Colors.white,
  );

  static AppPalette of(BuildContext context) => Theme.of(context).extension<AppPalette>() ?? _light;

  LinearGradient get heroGradient => LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [heroStart, heroEnd]);

  @override
  AppPalette copyWith({Color? success, Color? warning, Color? info, Color? leave, Color? neutral, Color? heroStart, Color? heroEnd, Color? onHero}) => AppPalette(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        info: info ?? this.info,
        leave: leave ?? this.leave,
        neutral: neutral ?? this.neutral,
        heroStart: heroStart ?? this.heroStart,
        heroEnd: heroEnd ?? this.heroEnd,
        onHero: onHero ?? this.onHero,
      );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      leave: Color.lerp(leave, other.leave, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      onHero: Color.lerp(onHero, other.onHero, t)!,
    );
  }
}
