import 'package:flutter/material.dart';

/// True unless the user (or OS) asked for reduced motion.
bool motionOk(BuildContext context) => !MediaQuery.disableAnimationsOf(context);

/// Fades and slides its child in once when first built. Later items start a little later,
/// so a grid or list cascades in instead of popping in all at once.
class StaggerIn extends StatelessWidget {
  const StaggerIn({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  static const _step = 60, _base = 380, _maxIndex = 10;

  @override
  Widget build(BuildContext context) {
    if (!motionOk(context)) return child;
    final i = index.clamp(0, _maxIndex);
    final total = _base + i * _step;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(i * _step / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: child),
      ),
      child: child,
    );
  }
}

final _number = RegExp(r'^(\D*?)(-?\d+(?:\.\d+)?)(.*)$');

/// Shows [text] and, if it contains a number ("12", "3.5 h", "40%"), counts up to it.
/// Changing the value animates from the previous number to the new one.
class CountUpText extends StatelessWidget {
  const CountUpText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final m = _number.firstMatch(text);
    if (m == null || !motionOk(context)) return Text(text, style: style);
    final target = double.parse(m.group(2)!);
    final decimals = m.group(2)!.contains('.') ? m.group(2)!.split('.').last.length : 0;
    final prefix = m.group(1)!, suffix = m.group(3)!;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('$prefix${v.toStringAsFixed(decimals)}$suffix', style: style),
    );
  }
}
