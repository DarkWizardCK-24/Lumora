import 'package:flutter/material.dart';
import '../colors/app_colors.dart';

/// [seed] recolours the whole app; [amoled] swaps the dark theme's greys for true black.
ThemeData buildTheme(Brightness b, {Color seed = Palette.brand, bool amoled = false}) {
  final dark = b == Brightness.dark;
  final black = dark && amoled;
  final surface = black ? const Color(0xFF0A0A0A) : (dark ? const Color(0xFF111827) : Palette.surface);
  final background = black ? Colors.black : (dark ? const Color(0xFF0B1220) : Palette.bg);
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b, surface: surface)
      .copyWith(primary: dark ? _darkPrimary(seed) : seed);
  final border = black ? const Color(0xFF1F1F1F) : (dark ? const Color(0xFF263244) : Palette.border);
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Manrope',
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    dividerTheme: DividerThemeData(color: border, space: 1),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg), side: BorderSide(color: border)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: black ? const Color(0xFF111111) : (dark ? const Color(0xFF16202F) : const Color(0xFFF8FAFC)),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm), borderSide: BorderSide(color: border)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide(color: border),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
      labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
    ),
    textTheme: Typography.blackMountainView.apply(
      fontFamily: 'Manrope',
      bodyColor: dark ? const Color(0xFFE2E8F0) : Palette.ink,
      displayColor: dark ? const Color(0xFFE2E8F0) : Palette.ink,
    ),
  );
}

/// Brightens a seed for dark surfaces. The default brand keeps its hand-picked cyan.
Color _darkPrimary(Color seed) {
  if (seed == Palette.brand) return const Color(0xFF22D3EE);
  final hsl = HSLColor.fromColor(seed);
  return hsl.withLightness(hsl.lightness.clamp(0.62, 0.75)).withSaturation((hsl.saturation * 0.95).clamp(0.0, 1.0)).toColor();
}
