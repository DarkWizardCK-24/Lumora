import 'package:flutter/material.dart';
import '../../core/utils/responsive.dart';

/// Standard content card with optional title and trailing actions.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.trailing, required this.child, this.padding});
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding ?? EdgeInsets.all(Responsive.isCompact(context) ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Expanded(
                      child: Text(title!,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700))),
                  if (trailing != null) Flexible(child: Align(alignment: Alignment.centerRight, child: trailing!)),
                ]),
              ),
            child,
          ],
        ),
      ),
    );
  }
}
