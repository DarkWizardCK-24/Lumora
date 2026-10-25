import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/colors/app_colors.dart';

/// A card that rotates around its vertical axis to reveal the back.
class FlipCard extends StatelessWidget {
  const FlipCard({super.key, required this.front, required this.back, required this.flipped, this.onTap});
  final String front, back;
  final bool flipped;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: flipped ? math.pi : 0),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
        builder: (context, angle, _) {
          final showBack = angle > math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: showBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(math.pi),
                    child: _face(back, 'ANSWER', Grads.emerald))
                : _face(front, 'QUESTION', Grads.indigo),
          );
        },
      ),
    );
  }

  Widget _face(String text, String tag, List<Color> colors) {
    return Container(
      constraints: const BoxConstraints(minHeight: 260),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg + 4),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(tag, style: const TextStyle(color: Colors.white70, letterSpacing: 2, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 14),
        Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600, height: 1.35)),
        const SizedBox(height: 14),
        if (tag == 'QUESTION')
          const Text('Tap or press Space to flip', style: TextStyle(color: Colors.white60, fontSize: 12)),
      ]),
    );
  }
}
