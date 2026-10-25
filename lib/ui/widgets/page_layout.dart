import 'package:flutter/material.dart';
import '../../core/colors/app_colors.dart';
import '../../core/utils/responsive.dart';

/// Page body: scrollable, padded and capped to a readable width on huge screens.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 1500, this.controller});
  final List<Widget> children;
  final double maxWidth;
  final ScrollController? controller;
  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(compact ? 16 : 24, compact ? 12 : 20, compact ? 16 : 24, 96),
          children: children,
        ),
      ),
    );
  }
}

/// Header row used at the top of pages: title/subtitle with wrapping actions.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const []});
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              if (subtitle != null)
                Text(subtitle!, style: t.textTheme.bodyMedium?.copyWith(color: Palette.muted)),
            ]),
          ),
          if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }
}
