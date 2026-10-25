import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/colors/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../widgets/adaptive_shell.dart';
import '../widgets/page_layout.dart';

/// Mobile "More" tab: every page that isn't a bottom tab.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final items = navItems.where((n) => !['/', '/goals', '/calendar', '/analytics'].contains(n.path)).toList();
    return PageBody(children: [
      AdaptiveGrid(
        minTile: 150,
        maxColumns: 3,
        minColumns: 2,
        children: [
          for (final n in items)
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.lg),
                onTap: () => context.go(n.path),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(n.selectedIcon, color: Theme.of(context).colorScheme.primary, size: 28),
                    const SizedBox(height: 14),
                    Text(n.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    ]);
  }
}
