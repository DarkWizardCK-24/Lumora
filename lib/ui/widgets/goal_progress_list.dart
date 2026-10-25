import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/colors/app_colors.dart';
import '../../core/colors/status_colors.dart';
import '../../core/models/enums.dart';
import '../../core/services/goal_analyzer.dart';
import '../../core/utils/format.dart';
import 'progress_bar.dart';

class GoalProgressList extends StatelessWidget {
  const GoalProgressList(this.analyses, {super.key});
  final List<GoalAnalysis> analyses;
  @override
  Widget build(BuildContext context) {
    final list = analyses
        .where((a) => a.goal.status != GoalStatus.completed)
        .take(5)
        .toList();
    if (list.isEmpty) {
      return const Text('No active goals yet.', style: TextStyle(color: Palette.muted));
    }
    return Column(children: [
      for (final a in list)
        InkWell(
          borderRadius: BorderRadius.circular(Radii.sm),
          onTap: () => context.go('/goals/${a.goal.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(a.goal.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                Text('${(a.progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              ProgressBar(a.progress, color: deadlineColor(a.status)),
              const SizedBox(height: 4),
              Text(a.goal.deadline == null ? 'No deadline' : 'Due ${fmtDate(a.goal.deadline!)} · ${a.status.label}',
                  style: const TextStyle(color: Palette.muted, fontSize: 12)),
            ]),
          ),
        ),
    ]);
  }
}
