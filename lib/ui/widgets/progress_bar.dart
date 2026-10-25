import 'package:flutter/material.dart';

class ProgressBar extends StatelessWidget {
  const ProgressBar(this.value, {super.key, this.color, this.height = 8});
  final double value;
  final Color? color;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: height,
          color: color ?? Theme.of(context).colorScheme.primary,
          backgroundColor: (color ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.14),
        ),
      );
}
