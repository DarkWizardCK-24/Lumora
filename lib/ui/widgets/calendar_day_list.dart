import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/repository.dart';
import '../../core/services/snapshot.dart';
import '../flows/activity_flow.dart';
import 'calendar_item.dart';
import 'confirmation_dialog.dart';

class CalendarDayList extends ConsumerWidget {
  const CalendarDayList(this.day, this.items, this.s, {super.key, this.bare = false});
  final DateTime day;
  final List<CalendarItem> items;
  final Snapshot s;
  final bool bare;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = items.where((i) => sameDay(i.when, day)).toList()..sort((a, b) => a.when.compareTo(b.when));
    if (list.isEmpty) return const Text('Nothing planned.', style: TextStyle(color: Palette.muted, fontSize: 13));
    final repo = ref.read(repoProvider);
    return Column(children: [
      for (final i in list)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(color: i.color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border(left: BorderSide(color: i.color, width: 3))),
          child: ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.only(left: 8, right: 0),
            leading: i.activity == null
                ? Icon(i.icon, color: i.color)
                : Checkbox(
                    value: i.activity!.done,
                    onChanged: (v) {
                      i.activity!.status = v == true ? 'done' : 'planned';
                      repo.saveActivity(i.activity!);
                    }),
            title: Text(i.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(decoration: i.activity?.done == true ? TextDecoration.lineThrough : null, fontWeight: FontWeight.w600)),
            subtitle: i.sub.isEmpty ? null : Text(i.sub, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: i.activity == null
                ? null
                : PopupMenuButton<String>(
                    tooltip: 'Activity actions',
                    onSelected: (v) async {
                      final a = i.activity!;
                      switch (v) {
                        case 'edit':
                          await editActivity(context, ref, s, activity: a);
                        case 'tomorrow':
                          a.plannedStart += const Duration(days: 1).inMilliseconds;
                          a.plannedEnd += const Duration(days: 1).inMilliseconds;
                          await repo.saveActivity(a);
                        case 'skip':
                          a.status = 'skipped';
                          await repo.saveActivity(a);
                        case 'delete':
                          if (await confirm(context, 'Delete activity?', 'Remove "${a.title}" from your plan?')) {
                            await repo.deleteActivity(a.id);
                          }
                      }
                    },
                    itemBuilder: (c) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit / reschedule')),
                      PopupMenuItem(value: 'tomorrow', child: Text('Move to tomorrow')),
                      PopupMenuItem(value: 'skip', child: Text('Skip')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
          ),
        ),
    ]);
  }
}
