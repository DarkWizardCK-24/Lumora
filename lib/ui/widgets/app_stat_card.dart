import 'package:flutter/material.dart';
import '../../core/colors/app_colors.dart';
import '../../core/utils/motion.dart';
import '../../core/utils/responsive.dart';

/// Gradient KPI tile: uppercase label, icon chip, big value and a pill footer.
class StatCard extends StatefulWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.footer,
    required this.icon,
    required this.colors,
    this.onTap,
  });
  final String label, value, footer;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback? onTap;

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    final pad = compact ? 14.0 : 20.0;
    final valueSize = compact ? 26.0 : 34.0;
    return Semantics(
      button: widget.onTap != null,
      label: '${widget.label}: ${widget.value}. ${widget.footer}',
      child: MouseRegion(
        cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.lg),
            boxShadow: [
              BoxShadow(
                color: widget.colors.last.withValues(alpha: _hover ? 0.35 : 0.18),
                blurRadius: _hover ? 22 : 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.lg),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight, colors: widget.colors),
              ),
              child: InkWell(
                onTap: widget.onTap,
                child: Stack(
                  children: [
                    Positioned(
                        right: -30,
                        top: -34,
                        child: _circle(120, 0.10)),
                    Positioned(
                        right: 30,
                        bottom: -56,
                        child: _circle(110, 0.08)),
                    Padding(
                      padding: EdgeInsets.all(pad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    widget.label.toUpperCase(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.92),
                                      fontSize: compact ? 10 : 12.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: compact ? 0.3 : 0.8,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: compact ? 30 : 42,
                                height: compact ? 30 : 42,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                                ),
                                child: Icon(widget.icon, color: Colors.white, size: compact ? 16 : 22),
                              ),
                            ],
                          ),
                          SizedBox(height: compact ? 14 : 22),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: CountUpText(widget.value,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: valueSize,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1)),
                          ),
                          SizedBox(height: compact ? 10 : 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(widget.footer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    fontSize: compact ? 11 : 12.5,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _circle(double d, double a) => Container(
      width: d,
      height: d,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: a)));
}
