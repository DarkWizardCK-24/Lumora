import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/colors/app_colors.dart';
import '../../core/models/enums.dart';
import '../../core/services/snapshot.dart';
import '../../core/utils/format.dart';
import 'pill.dart';

class DeadlinesList extends StatelessWidget {
  const DeadlinesList(this.s, {super.key});
  final Snapshot s;
  @override
  Widget build(BuildContext context) {
    final items = <(DateTime, String, String, String)>[
      for (final g in s.goals.where((g) => g.deadline != null && g.status != GoalStatus.completed && !g.archived))
        (g.deadline!, g.title, 'Goal', '/goals/${g.id}'),
      for (final m in s.milestones.where((m) => m.dueDate != null && !m.done))
        (m.dueDate!, m.title, 'Milestone', '/milestones'),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    if (items.isEmpty) {
      return const Text('No deadlines set.', style: TextStyle(color: Palette.muted));
    }
    return Column(children: [
      for (final i in items.take(5))
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          onTap: () => context.go(i.$4),
          title: Text(i.$2, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${i.$3} · ${fmtDate(i.$1)}'),
          trailing: Pill(
              () {
                final d = i.$1.difference(s.today).inDays;
                return d < 0 ? '${-d}d overdue' : d == 0 ? 'Today' : '${d}d';
              }(),
              color: i.$1.difference(s.today).inDays < 0
                  ? Palette.danger
                  : i.$1.difference(s.today).inDays <= 7
                      ? Palette.warning
                      : Theme.of(context).colorScheme.primary),
        ),
    ]);
  }
}
