import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors/app_colors.dart';
import '../../core/models/goal.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/repository.dart';
import '../../core/services/schedule_generator.dart';
import '../../core/services/snapshot.dart';
import '../../core/utils/format.dart';
import '../utils/app_snack.dart';

/// Shows the proposed schedule and only applies it after the user confirms.
/// Completed activities are never touched.
Future<void> previewSchedule(BuildContext context, WidgetRef ref, Snapshot s, Goal g) async {
  final plan = ScheduleGenerator.generate(g, s);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Review proposed plan'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 460),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${plan.activities.length} activities will be added. '
                '${plan.removedCount} older generated, unfinished activities will be replaced. '
                '${plan.keptCount} existing activities (including everything completed) are kept.'),
            if (!plan.fits)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Palette.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(Radii.sm)),
                child: Text(
                    '${fmtDuration(plan.unscheduledMinutes)} of work does not fit in your available time before the deadline. '
                    'Nothing was over-scheduled. Consider reducing scope, extending the deadline, or raising your availability in Settings.',
                    style: const TextStyle(color: Palette.danger)),
              ),
            const SizedBox(height: 10),
            for (final a in plan.activities.take(30))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${fmtDateTime(a.start)} · ${fmtMinutes(a.plannedMinutes)} · ${a.kind.label}'),
              ),
            if (plan.activities.length > 30) Text('…and ${plan.activities.length - 30} more'),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(
            onPressed: plan.activities.isEmpty && plan.removedCount == 0 ? null : () => Navigator.pop(c, true),
            child: const Text('Apply plan')),
      ],
    ),
  );
  if (ok != true) return;
  await ref.read(repoProvider).applySchedule(g.id, plan.activities, 'Plan generated from Smart Analysis');
  if (context.mounted) toast(context, 'Plan applied — see it in Calendar');
}
