import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/activity.dart';
import '../../core/models/enums.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/repository.dart';
import '../../core/services/snapshot.dart';
import '../../core/utils/pickers.dart';
import '../widgets/form_dialog.dart';

Future<void> editActivity(BuildContext context, WidgetRef ref, Snapshot s, {Activity? activity, DateTime? day}) async {
  final base = day ?? DateTime.now();
  final v = await showForm(context,
      title: activity == null ? 'Schedule activity' : 'Edit activity',
      fields: [
        const FText('title', 'Title', required: true),
        FChoice('kind', 'Type', {
          for (final k in ActivityKind.values.where((k) => k != ActivityKind.deadline && k != ActivityKind.milestone)) k.name: k.label
        }),
        FChoice('goalId', 'Goal', goalOptions(s), allowNone: true),
        FChoice('subjectId', 'Subject', subjectOptions(s), allowNone: true),
        const FDateTime('start', 'Planned start'),
        const FNumber('minutes', 'Planned duration', required: true, suffix: 'minutes'),
        const FChoice('priority', 'Priority', {'1': 'Low', '2': 'Medium', '3': 'High'}),
        const FText('criteria', 'Completion criteria', multiline: true),
        const FText('notes', 'Notes', multiline: true),
      ],
      initial: {
        'title': activity?.title,
        'kind': activity?.kind.name ?? 'study',
        'goalId': activity?.goalId,
        'subjectId': activity?.subjectId,
        'start': activity?.start ?? DateTime(base.year, base.month, base.day, s.studyHour),
        'minutes': activity?.plannedMinutes ?? 45,
        'priority': '${activity?.priority ?? 2}',
        'criteria': activity?.criteria,
        'notes': activity?.notes,
      });
  if (v == null) return;
  final start = (v['start'] as DateTime?) ?? DateTime(base.year, base.month, base.day, s.studyHour);
  final mins = ((v['minutes'] as int?) ?? 30).clamp(5, 600);
  final a = activity ??
      Activity(title: v['title'] as String, plannedStart: start.millisecondsSinceEpoch, plannedEnd: start.millisecondsSinceEpoch);
  a
    ..title = v['title'] as String
    ..kind = ActivityKind.values.byName((v['kind'] as String?) ?? 'study')
    ..goalId = v['goalId'] as String?
    ..subjectId = v['subjectId'] as String?
    ..plannedStart = start.millisecondsSinceEpoch
    ..plannedMinutes = mins
    ..plannedEnd = start.add(Duration(minutes: mins)).millisecondsSinceEpoch
    ..priority = int.parse((v['priority'] as String?) ?? '2')
    ..criteria = (v['criteria'] as String?) ?? ''
    ..notes = (v['notes'] as String?) ?? '';
  await ref.read(repoProvider).saveActivity(a);
}
