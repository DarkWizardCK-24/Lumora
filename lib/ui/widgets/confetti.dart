import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/utils/motion.dart';

/// One-shot confetti burst that fills its parent. Renders nothing when motion is reduced.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.colors = _defaultColors});
  final List<Color> colors;
  static const _defaultColors = [
    Color(0xFFF59E0B),
    Color(0xFF22D3EE),
    Color(0xFFEC4899),
    Color(0xFF10B981),
    Color(0xFF8B5CF6),
    Color(0xFFEF4444),
  ];

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();
  late final _pieces = _make();

  List<_Piece> _make() {
    final r = math.Random(7);
    return List.generate(
        70,
        (_) => _Piece(
            angle: -math.pi / 2 + (r.nextDouble() - 0.5) * math.pi * 1.1,
            speed: 260 + r.nextDouble() * 420,
            spin: (r.nextDouble() - 0.5) * 14,
            size: 6 + r.nextDouble() * 6,
            color: widget.colors[r.nextInt(widget.colors.length)]));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!motionOk(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(painter: _ConfettiPainter(_pieces, _c.value), size: Size.infinite),
      ),
    );
  }
}

class _Piece {
  const _Piece({required this.angle, required this.speed, required this.spin, required this.size, required this.color});
  final double angle, speed, spin, size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.45);
    final seconds = t * 2.6;
    for (final p in pieces) {
      final pos = origin +
          Offset(math.cos(p.angle) * p.speed * seconds, math.sin(p.angle) * p.speed * seconds + 520 * seconds * seconds);
      final paint = Paint()..color = p.color.withValues(alpha: (1 - t * t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * seconds);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55), const Radius.circular(2)),
          paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
