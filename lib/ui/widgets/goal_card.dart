import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/colors/app_colors.dart';
import '../../core/colors/status_colors.dart';
import '../../core/models/enums.dart';
import '../../core/models/goal.dart';
import '../../core/services/goal_analyzer.dart';
import '../../core/services/snapshot.dart';
import '../../core/utils/format.dart';
import 'pill.dart';
import 'progress_bar.dart';

class GoalCard extends StatelessWidget {
  const GoalCard(this.goal, this.s, {super.key, this.dense = false});
  final Goal goal;
  final Snapshot s;
  final bool dense;
  @override
  Widget build(BuildContext context) {
    final a = GoalAnalyzer.analyze(goal, s);
    final subj = s.subjects.where((x) => x.id == goal.subjectId).firstOrNull;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: () => context.go('/goals/${goal.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (subj != null)
                Hero(
                  tag: 'goal-icon-${goal.id}',
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(color: Color(subj.color).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                    child: Icon(iconFor(subj.icon), size: 18, color: Color(subj.color)),
                  ),
                ),
              Expanded(
                  child: Text(goal.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5))),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              Pill(goal.status.label, color: statusColor(goal.status)),
              Pill(a.status.label, color: deadlineColor(a.status)),
              Pill('${priorityLabels[goal.priority]} priority', color: Palette.muted),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: ProgressBar(a.progress, color: deadlineColor(a.status))),
              const SizedBox(width: 10),
              Text('${(a.progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            Text(
                [
                  goal.deadline == null ? 'No deadline' : 'Due ${fmtDate(goal.deadline!)}',
                  if (a.loggedMinutes > 0) '${fmtMinutes(a.loggedMinutes)} logged',
                ].join(' · '),
                style: const TextStyle(color: Palette.muted, fontSize: 12.5)),
          ]),
        ),
      ),
    );
  }
}
