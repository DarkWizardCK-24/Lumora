import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/colors/app_colors.dart';
import '../../core/models/activity.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/repository.dart';
import '../../core/services/snapshot.dart';
import '../../core/utils/format.dart';
import 'section_card.dart';

class TodayPlanCard extends ConsumerWidget {
  const TodayPlanCard(this.s, {super.key});
  final Snapshot s;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final from = s.today;
    final to = from.add(const Duration(days: 1));
    final acts = s.activities
        .where((a) => !a.start.isBefore(from) && a.start.isBefore(to) && a.status != 'skipped')
        .toList();
    final plannedTotal = acts.fold<int>(0, (a, b) => a + b.plannedMinutes);
    final actual = s.minutesOn(s.today);
    return SectionCard(
      title: "Today's plan",
      trailing: TextButton(onPressed: () => context.go('/calendar?new=1'), child: const Text('Schedule')),
      child: acts.isEmpty
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Nothing scheduled for today.', style: TextStyle(color: Palette.muted)),
              const SizedBox(height: 8),
              Text('Studied so far: ${fmtMinutes(actual)}'),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Planned ${fmtMinutes(plannedTotal)} · actual ${fmtMinutes(actual)}',
                  style: const TextStyle(color: Palette.muted)),
              const SizedBox(height: 6),
              for (final a in acts)
                Dismissible(
                  key: ValueKey('plan-${a.id}'),
                  background: _swipeBg(Palette.success, Icons.check_circle_rounded, 'Done', Alignment.centerLeft),
                  secondaryBackground: _swipeBg(Palette.warning, Icons.snooze_rounded, 'Tomorrow', Alignment.centerRight),
                  // Act on the swipe but keep the row: the list refreshes itself from the database.
                  confirmDismiss: (dir) async {
                    HapticFeedback.mediumImpact();
                    if (dir == DismissDirection.startToEnd) {
                      a.status = 'done';
                      await ref.read(repoProvider).saveActivity(a);
                    } else {
                      await _snooze(context, ref, a);
                    }
                    return false;
                  },
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: a.done,
                    title: Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${DateFormat.jm().format(a.start)} · ${fmtMinutes(a.plannedMinutes)}'),
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      a.status = v == true ? 'done' : 'planned';
                      ref.read(repoProvider).saveActivity(a);
                    },
                  ),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Swipe right to complete, left to move to tomorrow', style: TextStyle(color: Palette.muted, fontSize: 11.5)),
              ),
            ]),
    );
  }
}

Widget _swipeBg(Color color, IconData icon, String label, Alignment align) => Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: align,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(Radii.sm)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      ]),
    );

/// Moves an activity to the same time tomorrow, with an undo.
Future<void> _snooze(BuildContext context, WidgetRef ref, Activity a) async {
  final repo = ref.read(repoProvider);
  final oldStart = a.plannedStart, oldEnd = a.plannedEnd;
  const day = 24 * 3600 * 1000;
  a
    ..plannedStart = oldStart + day
    ..plannedEnd = oldEnd + day;
  await repo.saveActivity(a);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: const Text('Moved to tomorrow'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          a
            ..plannedStart = oldStart
            ..plannedEnd = oldEnd;
          repo.saveActivity(a);
        },
      ),
    ));
}
