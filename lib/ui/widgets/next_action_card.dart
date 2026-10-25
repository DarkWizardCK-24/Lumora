import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/colors/app_colors.dart';
import '../../core/colors/status_colors.dart';
import '../../core/models/enums.dart';
import '../../core/services/goal_analyzer.dart';
import '../../core/services/snapshot.dart';
import 'pill.dart';
import 'section_card.dart';

class NextActionCard extends StatelessWidget {
  const NextActionCard(this.s, this.analyses, {super.key});
  final Snapshot s;
  final List<GoalAnalysis> analyses;
  @override
  Widget build(BuildContext context) {
    final cand = analyses
        .where((a) => a.goal.status != GoalStatus.completed && a.goal.status != GoalStatus.paused)
        .toList()
      ..sort((a, b) {
        int rank(DeadlineStatus d) => switch (d) {
              DeadlineStatus.passed => 0,
              DeadlineStatus.unlikely => 1,
              DeadlineStatus.atRisk => 2,
              DeadlineStatus.adjustments => 3,
              _ => 4,
            };
        final r = rank(a.status).compareTo(rank(b.status));
        return r != 0 ? r : (a.daysLeft ?? 9999).compareTo(b.daysLeft ?? 9999);
      });
    final top = cand.isEmpty ? null : cand.first;
    return SectionCard(
      title: 'Smart next action',
      child: top == null
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Create a goal and Lumora will recommend what to do each day, based on deadlines and your pace.',
                  style: TextStyle(color: Palette.muted)),
              const SizedBox(height: 12),
              FilledButton.icon(
                  onPressed: () => context.go('/goals?new=1'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add a goal')),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(top.goal.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Pill(top.status.label, color: deadlineColor(top.status)),
              ]),
              const SizedBox(height: 8),
              Text(top.nextAction),
              if (top.daysLeft != null) ...[
                const SizedBox(height: 6),
                Text(top.daysLeft! < 0 ? 'Overdue' : '${top.daysLeft} days left',
                    style: const TextStyle(color: Palette.muted)),
              ],
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                    onPressed: () => context.go('/sessions'),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start session')),
                OutlinedButton(
                    onPressed: () => context.go('/analysis'), child: const Text('Analyze')),
              ]),
            ]),
    );
  }
}
