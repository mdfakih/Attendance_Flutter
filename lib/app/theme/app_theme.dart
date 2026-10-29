import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'branding.dart';

/// Material 3 light and dark themes in the client's brand colours over crisp neutral surfaces.
abstract final class AppTheme {
  static ThemeData light(Branding branding) => _build(branding, Brightness.light);
  static ThemeData dark(Branding branding) => _build(branding, Brightness.dark);

  static const radius = 18.0;

  /// Readable text/icon colour on [background].
  static Color onColor(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark ? Colors.white : const Color(0xFF0B1020);

  /// Lighter (positive) or darker (negative) version of [color].
  static Color shade(Color color, double delta) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
  }

  /// Brand colours read well on dark surfaces only when light enough.
  static Color forDark(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.lightness >= 0.64 ? color : hsl.withLightness(0.7).toColor();
  }

  static ThemeData _build(Branding branding, Brightness brightness) {
    final scheme = _scheme(branding, brightness);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
    final text = _text(base.textTheme, scheme);
    final isDark = brightness == Brightness.dark;
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return base.copyWith(
      scaffoldBackgroundColor: isDark ? const Color(0xFF0B1020) : const Color(0xFFF4F6FA),
      textTheme: text,
      extensions: [_palette(branding, isDark)],
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF0B1020) : const Color(0xFFF4F6FA),
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: scheme.outlineVariant)),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(64, 52), shape: rounded, textStyle: text.labelLarge?.copyWith(fontSize: 16)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48), shape: rounded, side: BorderSide(color: scheme.outline), textStyle: text.labelLarge),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(minimumSize: const Size(48, 44), shape: rounded, textStyle: text.labelLarge)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF141C2E) : const Color(0xFFF8F9FC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.error, width: 2)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.22 : 0.12),
        iconTheme: WidgetStateProperty.resolveWith((states) =>
            IconThemeData(color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant, size: 24)),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => text.labelMedium?.copyWith(
              color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            )),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surface,
        labelStyle: text.labelMedium,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: text.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      listTileTheme: ListTileThemeData(iconColor: scheme.onSurfaceVariant, contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary, linearTrackColor: scheme.primary.withValues(alpha: 0.15)),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primary.withValues(alpha: isDark ? 0.24 : 0.12),
          selectedForegroundColor: scheme.primary,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: text.labelLarge,
        ),
      ),
    );
  }

  static ColorScheme _scheme(Branding branding, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? forDark(branding.primary) : branding.primary;
    final accent = isDark ? forDark(branding.accent) : branding.accent;
    final seeded = ColorScheme.fromSeed(seedColor: branding.primary, brightness: brightness, dynamicSchemeVariant: DynamicSchemeVariant.fidelity);
    final surface = isDark ? const Color(0xFF121A2B) : Colors.white;
    return seeded.copyWith(
      primary: primary,
      onPrimary: onColor(primary),
      secondary: accent,
      onSecondary: onColor(accent),
      secondaryContainer: Color.lerp(surface, accent, isDark ? 0.28 : 0.14),
      onSecondaryContainer: isDark ? shade(accent, 0.12) : shade(accent, -0.22),
      surface: surface,
      onSurface: isDark ? const Color(0xFFE6E9F2) : const Color(0xFF0F172A),
      onSurfaceVariant: isDark ? const Color(0xFF9AA4B8) : const Color(0xFF5B6475),
      surfaceContainerLowest: isDark ? const Color(0xFF0E1525) : Colors.white,
      surfaceContainerLow: isDark ? const Color(0xFF141C2E) : const Color(0xFFF8F9FC),
      surfaceContainer: isDark ? const Color(0xFF182134) : const Color(0xFFF2F4F8),
      surfaceContainerHigh: isDark ? const Color(0xFF1D2740) : const Color(0xFFECEFF4),
      surfaceContainerHighest: isDark ? const Color(0xFF232E49) : const Color(0xFFE5E8EF),
      outline: isDark ? const Color(0xFF3A4560) : const Color(0xFFCBD2DC),
      outlineVariant: isDark ? const Color(0xFF263049) : const Color(0xFFE3E7EE),
      surfaceTint: Colors.transparent,
    );
  }

  static AppPalette _palette(Branding branding, bool isDark) {
    final start = isDark ? shade(branding.primary, -0.08) : branding.primary;
    final end = shade(Color.lerp(branding.primary, branding.accent, 0.55)!, isDark ? -0.12 : -0.04);
    return AppPalette(
      success: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
      warning: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
      info: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
      leave: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
      neutral: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      heroStart: start,
      heroEnd: end,
      onHero: onColor(Color.lerp(start, end, 0.5)!),
    );
  }

  static TextTheme _text(TextTheme base, ColorScheme scheme) => base.copyWith(
        displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
        headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
        titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: base.bodyMedium?.copyWith(height: 1.4),
        bodySmall: base.bodySmall?.copyWith(height: 1.4, color: scheme.onSurfaceVariant),
      );
}
