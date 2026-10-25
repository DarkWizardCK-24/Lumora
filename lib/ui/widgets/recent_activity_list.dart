import 'package:flutter/material.dart';
import '../../core/colors/app_colors.dart';
import '../../core/services/snapshot.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/format.dart';

class RecentActivityList extends StatelessWidget {
  const RecentActivityList(this.s, {super.key});
  final Snapshot s;
  @override
  Widget build(BuildContext context) {
    final items = <(int, IconData, String, String)>[
      for (final x in s.sessions.take(6))
        (x.startedAt, Icons.timer_outlined, '${x.type.label} session', '${fmtMinutes(x.activeSeconds / 60)} · ${fmtDateTime(fromMs(x.startedAt))}'),
      for (final p in s.problems.take(6))
        (p.attemptedAt, Icons.code, p.title, '${p.result.label} · ${p.platform}'),
      for (final m in s.milestones.where((m) => m.done).take(4))
        (m.completedAt!, Icons.emoji_events_outlined, 'Milestone: ${m.title}', 'Completed'),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    if (items.isEmpty) {
      return const Text('Your sessions, practice and milestones will appear here.', style: TextStyle(color: Palette.muted));
    }
    return Column(children: [
      for (final i in items.take(6))
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(i.$2, color: Theme.of(context).colorScheme.primary),
          title: Text(i.$3, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(i.$4, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
    ]);
  }
}
