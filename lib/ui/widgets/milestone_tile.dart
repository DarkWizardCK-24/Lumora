import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors/app_colors.dart';
import '../../core/models/milestone.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/repository.dart';
import '../../core/services/snapshot.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/format.dart';
import '../../core/utils/pickers.dart';
import '../flows/milestone_flow.dart';
import 'confirmation_dialog.dart';
import 'pill.dart';

class MilestoneTile extends ConsumerWidget {
  const MilestoneTile(this.m, this.s, {super.key, this.showGoal = false});
  final Milestone m;
  final Snapshot s;
  final bool showGoal;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue = !m.done && m.dueDate != null && m.dueDate!.isBefore(s.today);
    final repo = ref.read(repoProvider);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: m.done,
        onChanged: (v) {
          m.completedAt = v == true ? nowMs() : null;
          repo.saveMilestone(m);
        },
      ),
      title: Text(m.title,
          style: TextStyle(decoration: m.done ? TextDecoration.lineThrough : null, fontWeight: FontWeight.w600)),
      subtitle: Text([
        if (showGoal) goalTitleOf(s, m.goalId) ?? '',
        if (m.dueDate != null) 'Due ${fmtDate(m.dueDate!)}',
        if (m.done) 'Completed ${fmtDate(fromMs(m.completedAt!))}',
        if (m.criteria.isNotEmpty) m.criteria,
      ].where((e) => e.isNotEmpty).join(' · ')),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (overdue) const Pill('Overdue', color: Palette.danger),
        PopupMenuButton<String>(
          tooltip: 'More',
          onSelected: (v) async {
            if (v == 'edit') {
              await editMilestone(context, ref, s, milestone: m);
            } else if (await confirm(context, 'Delete milestone?', 'This removes "${m.title}".')) {
              await repo.deleteMilestone(m.id);
            }
          },
          itemBuilder: (c) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ]),
    );
  }
}
