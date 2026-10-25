import 'package:flutter/material.dart';

/// Lumora design tokens. Light theme is the default; dark is available.
class Palette {
  static const brand = Color(0xFF0E7490); // deep cyan
  static const brandBlue = Color(0xFF2563EB);
  static const bg = Color(0xFFF3F6FB);
  static const surface = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const success = Color(0xFF059669);
  static const warning = Color(0xFFF97316);
  static const danger = Color(0xFFDC2626);
}

/// Two-stop gradients for the stat cards — each one a different hue.
class Grads {
  static const indigo = [Color(0xFF6366F1), Color(0xFF4F46E5)];
  static const emerald = [Color(0xFF10B981), Color(0xFF059669)];
  static const red = [Color(0xFFEF4444), Color(0xFFDC2626)];
  static const orange = [Color(0xFFF97316), Color(0xFFEA580C)];
  static const sky = [Color(0xFF0284C7), Color(0xFF0E7490)];
  static const violet = [Color(0xFF8B5CF6), Color(0xFF6D28D9)];
  static const teal = [Color(0xFF14B8A6), Color(0xFF0D9488)];
  static const rose = [Color(0xFFEC4899), Color(0xFFDB2777)];
  static const amber = [Color(0xFFF59E0B), Color(0xFFD97706)];
  static const slate = [Color(0xFF475569), Color(0xFF1E293B)];
}

class Gaps {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0, xxl = 32.0;
}

class Radii {
  static const sm = 10.0, md = 14.0, lg = 18.0;
}

const subjectColors = <int>[
  0xFF0E7490, 0xFF2563EB, 0xFF7C3AED, 0xFFDB2777, 0xFFEA580C, 0xFF059669, 0xFFD97706, 0xFF475569,
];

const subjectIcons = <String, IconData>{
  'book': Icons.menu_book_rounded,
  'code': Icons.code_rounded,
  'data': Icons.storage_rounded,
  'chart': Icons.bar_chart_rounded,
  'cloud': Icons.cloud_outlined,
  'shield': Icons.shield_outlined,
  'terminal': Icons.terminal_rounded,
  'phone': Icons.phone_android_rounded,
  'api': Icons.api_rounded,
  'build': Icons.build_circle_outlined,
  'psychology': Icons.psychology_outlined,
  'rocket': Icons.rocket_launch_outlined,
};

IconData iconFor(String key) => subjectIcons[key] ?? Icons.menu_book_rounded;
