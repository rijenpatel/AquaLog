import 'package:flutter/material.dart';

class AquaColors {
  // Brand Aquaculture Teals & Aquatic Tonal Palette
  static const primary = primaryLight;
  static const primaryLight = Color(0xFF004E59);
  static const onPrimaryLight = Color(0xFFFFFFFF);
  static const primaryContainer = primaryContainerLight;
  static const primaryContainerLight = Color(0xFF006876);
  static const onPrimaryContainerLight = Color(0xFF97E4F4);
  static const primaryFixed = Color(0xFFA2EFFF);
  static const primaryFixedDim = Color(0xFF85D2E2);

  static const secondary = secondaryLight;
  static const secondaryLight = Color(0xFF4A6267);
  static const onSecondaryLight = Color(0xFFFFFFFF);
  static const secondaryContainer = secondaryContainerLight;
  static const secondaryContainerLight = Color(0xFFCDE7ED);
  static const onSecondaryContainerLight = Color(0xFF50686D);

  static const tertiaryLight = Color(0xFF3A4664);
  static const onTertiaryLight = Color(0xFFFFFFFF);
  static const tertiaryContainerLight = Color(0xFF525E7D);
  static const onTertiaryContainerLight = Color(0xFFCCD8FD);

  // Surfaces - M3 Light Containers
  static const surfaceLight = Color(0xFFF2FBFD);
  static const surfaceDimLight = Color(0xFFD3DCDE);
  static const surfaceBrightLight = Color(0xFFF2FBFD);
  static const surfaceContainerLowestLight = Color(0xFFFFFFFF);
  static const surfaceContainerLowLight = Color(0xFFECF5F7);
  static const surfaceContainerLight = Color(0xFFE6EFF1);
  static const surfaceContainerHighLight = Color(0xFFE1EAEC);
  static const surfaceContainerHighestLight = Color(0xFFDBE4E6);
  static const onSurfaceLight = Color(0xFF151D1F);
  static const onSurfaceVariantLight = Color(0xFF3F484B);
  static const outlineLight = Color(0xFF6F797B);
  static const outlineVariantLight = Color(0xFFBEC8CB);

  // Dark Palette
  static const surfaceDark = Color(0xFF0E1415);
  static const surfaceContainerLowestDark = Color(0xFF080D0E);
  static const surfaceContainerLowDark = Color(0xFF131A1C);
  static const surfaceContainerDark = Color(0xFF171E20);
  static const surfaceContainerHighDark = Color(0xFF1C2426);
  static const surfaceContainerHighestDark = Color(0xFF222B2D);
  static const onSurfaceDark = Color(0xFFE1EAEC);
  static const onSurfaceVariantDark = Color(0xFFBEC8CB);
  static const primaryDark = Color(0xFF85D2E2);
  static const primaryContainerDark = Color(0xFF004E59);
  static const onPrimaryDark = Color(0xFF00363E);
  static const onPrimaryContainerDark = Color(0xFFA2EFFF);

  // High-Contrast Outdoor Sunlight Palette
  static const outdoorBackground = Color(0xFF000000);
  static const outdoorSurface = Color(0xFF101622);
  static const outdoorSurfaceElevated = Color(0xFF182234);
  static const outdoorBorder = Color(0xFF00E5F5);
  static const outdoorText = Color(0xFFFFFFFF);
  static const outdoorTextSecondary = Color(0xFFD0E0E5);
  static const outdoorPrimary = Color(0xFF00E5F5);

  // Aquaculture Semantic Status Tokens
  static const statusOptimal = Color(0xFF10B981); // Emerald
  static const onStatusOptimal = Color(0xFFFFFFFF);
  static const statusWarning = Color(0xFFF59E0B); // Amber
  static const onStatusWarning = Color(0xFF000000);
  static const statusCritical = Color(0xFFEF4444); // Crimson Rose
  static const onStatusCritical = Color(0xFFFFFFFF);
  static const statusAlert = statusCritical;

  // Check-Tray Leftover Semantic Tokens
  static const trayClean = Color(0xFF10B981);   // 0% Clean
  static const trayNormal = Color(0xFF00ACC1);  // 1-10% Normal
  static const trayModerate = Color(0xFFF59E0B);// 11-25% Leftover
  static const traySurplus = Color(0xFFEF4444); // >25% Surplus

  // Pellet Sizes Palette
  static const pelletStarter = Color(0xFF38BDF8); // Sky Blue 0.8mm
  static const pelletGrower1 = Color(0xFF00C6D4); // Teal Cyan 1.2mm
  static const pelletGrower2 = Color(0xFF10B981); // Emerald 1.6mm
  static const pelletFinisher1 = Color(0xFFF59E0B);// Amber 2.0mm
  static const pelletFinisher2 = Color(0xFFA78BFA);// Purple 2.5mm
}

const ColorScheme lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: AquaColors.primaryLight,
  onPrimary: AquaColors.onPrimaryLight,
  primaryContainer: AquaColors.primaryContainerLight,
  onPrimaryContainer: AquaColors.onPrimaryContainerLight,
  secondary: AquaColors.secondaryLight,
  onSecondary: AquaColors.onSecondaryLight,
  secondaryContainer: AquaColors.secondaryContainerLight,
  onSecondaryContainer: AquaColors.onSecondaryContainerLight,
  tertiary: AquaColors.tertiaryLight,
  onTertiary: AquaColors.onTertiaryLight,
  tertiaryContainer: AquaColors.tertiaryContainerLight,
  onTertiaryContainer: AquaColors.onTertiaryContainerLight,
  error: Color(0xFFBA1A1A),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF93000A),
  surface: AquaColors.surfaceLight,
  onSurface: AquaColors.onSurfaceLight,
  surfaceContainerLowest: AquaColors.surfaceContainerLowestLight,
  surfaceContainerLow: AquaColors.surfaceContainerLowLight,
  surfaceContainer: AquaColors.surfaceContainerLight,
  surfaceContainerHigh: AquaColors.surfaceContainerHighLight,
  surfaceContainerHighest: AquaColors.surfaceContainerHighestLight,
  onSurfaceVariant: AquaColors.onSurfaceVariantLight,
  outline: AquaColors.outlineLight,
  outlineVariant: AquaColors.outlineVariantLight,
);

const ColorScheme darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: AquaColors.primaryDark,
  onPrimary: AquaColors.onPrimaryDark,
  primaryContainer: AquaColors.primaryContainerDark,
  onPrimaryContainer: AquaColors.onPrimaryContainerDark,
  secondary: Color(0xFFB1CBD1),
  onSecondary: Color(0xFF1B3438),
  secondaryContainer: Color(0xFF334B4F),
  onSecondaryContainer: Color(0xFFCDE7ED),
  tertiary: Color(0xFFBAC6EA),
  onTertiary: Color(0xFF24304D),
  tertiaryContainer: Color(0xFF3A4664),
  onTertiaryContainer: Color(0xFFD9E2FF),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: AquaColors.surfaceDark,
  onSurface: AquaColors.onSurfaceDark,
  surfaceContainerLowest: AquaColors.surfaceContainerLowestDark,
  surfaceContainerLow: AquaColors.surfaceContainerLowDark,
  surfaceContainer: AquaColors.surfaceContainerDark,
  surfaceContainerHigh: AquaColors.surfaceContainerHighDark,
  surfaceContainerHighest: AquaColors.surfaceContainerHighestDark,
  onSurfaceVariant: AquaColors.onSurfaceVariantDark,
  outline: Color(0xFF899395),
  outlineVariant: Color(0xFF3F484B),
);
