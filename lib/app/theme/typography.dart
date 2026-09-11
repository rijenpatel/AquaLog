import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AquaTypography {
  static TextTheme createTextTheme(Color onSurfaceColor, {bool isHindi = false}) {
    final baseStyle = isHindi
        ? GoogleFonts.notoSansDevanagari()
        : GoogleFonts.robotoFlex(fontFeatures: const [FontFeature.tabularFigures()]);

    return TextTheme(
      displayLarge: baseStyle.copyWith(
        fontSize: 57,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: onSurfaceColor,
      ),
      displayMedium: baseStyle.copyWith(
        fontSize: 45,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: onSurfaceColor,
      ),
      displaySmall: baseStyle.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: onSurfaceColor,
      ),
      headlineLarge: baseStyle.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: onSurfaceColor,
      ),
      headlineMedium: baseStyle.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        color: onSurfaceColor,
      ),
      headlineSmall: baseStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.15,
        color: onSurfaceColor,
      ),
      titleLarge: baseStyle.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
        color: onSurfaceColor,
      ),
      titleMedium: baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: onSurfaceColor,
      ),
      titleSmall: baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: onSurfaceColor,
      ),
      bodyLarge: baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        color: onSurfaceColor,
      ),
      bodyMedium: baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        color: onSurfaceColor,
      ),
      bodySmall: baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        color: onSurfaceColor,
      ),
      labelLarge: baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: onSurfaceColor,
      ),
      labelMedium: baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: onSurfaceColor,
      ),
      labelSmall: baseStyle.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: onSurfaceColor,
      ),
    );
  }

  /// Specialized tabular numeric style for KPI metric displays and counters
  static TextStyle numeric(
    BuildContext context, {
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double letterSpacing = -0.5,
  }) {
    final theme = Theme.of(context);
    return GoogleFonts.robotoFlex(
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color ?? theme.colorScheme.onSurface,
    );
  }
}
