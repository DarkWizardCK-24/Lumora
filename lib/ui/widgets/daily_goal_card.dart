import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/colors/app_colors.dart';
import '../../core/services/snapshot.dart';
import '../../core/utils/format.dart';
import 'progress_ring.dart';
import 'section_card.dart';

/// Today's progress toward the daily learning target, plus quick routes into focus and flashcards.
class DailyGoalCard extends StatelessWidget {
  const DailyGoalCard(this.s, this.targetMinutes, {super.key});
  final Snapshot s;
  final int targetMinutes;

  @override
  Widget build(BuildContext context) {
    final done = s.minutesOn(s.today);
    final progress = targetMinutes <= 0 ? 0.0 : done / targetMinutes;
    final reached = progress >= 1;
    final color = reached ? Palette.success : Theme.of(context).colorScheme.primary;
    final left = (targetMinutes - done).clamp(0, 1 << 30);
    return SectionCard(
      title: 'Daily goal',
      child: Row(children: [
        ProgressRing(
          value: progress,
          size: 92,
          stroke: 10,
          color: color,
          child: reached
              ? Icon(Icons.check_rounded, color: color, size: 34)
              : Text('${(progress * 100).clamp(0, 100).round()}%', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: color)),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${fmtMinutes(done)} of ${fmtMinutes(targetMinutes)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 2),
            Text(reached ? 'Goal reached. Anything more is a bonus.' : '${fmtMinutes(left)} to go today',
                style: const TextStyle(color: Palette.muted, fontSize: 12.5)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(48, 38), padding: const EdgeInsets.symmetric(horizontal: 14)),
                  onPressed: () => context.go('/focus'),
                  icon: const Icon(Icons.self_improvement_rounded, size: 18),
                  label: const Text('Focus')),
              if (s.cardsDue > 0)
                OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 38), padding: const EdgeInsets.symmetric(horizontal: 14)),
                    onPressed: () => context.go('/flashcards'),
                    icon: const Icon(Icons.style_rounded, size: 18),
                    label: Text('${s.cardsDue} cards due')),
            ]),
          ]),
        ),
      ]),
    );
  }
}
