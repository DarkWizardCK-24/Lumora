import 'package:flutter/material.dart';
import '../../core/colors/app_colors.dart';
import '../../core/colors/status_colors.dart';
import '../../core/models/enums.dart';
import '../../core/models/goal.dart';
import '../../core/services/snapshot.dart';
import 'goal_card.dart';
import 'pill.dart';

class GoalBoard extends StatelessWidget {
  const GoalBoard(this.goals, this.s, {super.key});
  final List<Goal> goals;
  final Snapshot s;
  @override
  Widget build(BuildContext context) {
    final cols = [GoalStatus.notStarted, GoalStatus.inProgress, GoalStatus.paused, GoalStatus.completed];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final c in cols)
          Container(
            width: 300,
            margin: const EdgeInsets.only(right: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Pill(c.label, color: statusColor(c)),
                  const SizedBox(width: 8),
                  Text('${goals.where((g) => g.status == c).length}', style: const TextStyle(color: Palette.muted)),
                ]),
              ),
              for (final g in goals.where((g) => g.status == c))
                Padding(padding: const EdgeInsets.only(bottom: 10), child: GoalCard(g, s, dense: true)),
            ]),
          ),
      ]),
    );
  }
}
