import 'package:flutter/material.dart';
import 'app_colors.dart';

/// A named colour theme. [seed] drives the Material colour scheme.
class AppPalette {
  const AppPalette(this.id, this.name, this.seed, this.icon);
  final String id, name;
  final Color seed;
  final IconData icon;
}

const appPalettes = <AppPalette>[
  AppPalette('ocean', 'Ocean', Palette.brand, Icons.water_rounded),
  AppPalette('sunset', 'Sunset', Color(0xFFEA580C), Icons.wb_twilight_rounded),
  AppPalette('forest', 'Forest', Color(0xFF15803D), Icons.park_rounded),
  AppPalette('midnight', 'Midnight', Color(0xFF6366F1), Icons.nightlight_round),
  AppPalette('rose', 'Rose', Color(0xFFDB2777), Icons.local_florist_rounded),
  AppPalette('lavender', 'Lavender', Color(0xFF7C3AED), Icons.auto_awesome_rounded),
];

/// Quick custom accent choices shown beside the presets.
const accentSwatches = <int>[
  0xFF0E7490, 0xFF2563EB, 0xFF7C3AED, 0xFFDB2777, 0xFFEA580C, 0xFF15803D, 0xFFCA8A04, 0xFF475569,
];

AppPalette paletteById(String id) =>
    appPalettes.firstWhere((p) => p.id == id, orElse: () => appPalettes.first);

/// The seed colour to build the theme from: a custom accent wins over the palette.
Color seedFor(String paletteId, int accentColor) =>
    accentColor != 0 ? Color(accentColor) : paletteById(paletteId).seed;
