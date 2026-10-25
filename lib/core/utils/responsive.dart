import 'package:flutter/material.dart';
import 'motion.dart';

enum Layout { compact, medium, expanded }

/// Layout is decided from available width, never from device names.
class Responsive {
  static const compactMax = 600.0;
  static const mediumMax = 900.0;

  static Layout of(double width) => width < compactMax
      ? Layout.compact
      : width < mediumMax
          ? Layout.medium
          : Layout.expanded;

  static Layout ctx(BuildContext c) => of(MediaQuery.sizeOf(c).width);
  static bool isCompact(BuildContext c) => ctx(c) == Layout.compact;

  /// Number of columns for a card grid given the width of its container.
  static int columns(double width, {double minTile = 240, int max = 4, int min = 1}) {
    final n = (width / minTile).floor();
    return n.clamp(min, max);
  }
}

/// Lays children out in equal-width columns that wrap, with no fixed heights
/// so content can never clip. Use [minTile] to control when it reflows.
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.children,
    this.minTile = 240,
    this.maxColumns = 4,
    this.minColumns = 1,
    this.spacing = 14,
  });
  final List<Widget> children;
  final double minTile, spacing;
  final int maxColumns, minColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = Responsive.columns(c.maxWidth, minTile: minTile, max: maxColumns, min: minColumns);
      final w = (c.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (var i = 0; i < children.length; i++) SizedBox(width: w, child: StaggerIn(index: i, child: children[i])),
        ],
      );
    });
  }
}
