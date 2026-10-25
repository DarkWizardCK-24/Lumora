import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/enums.dart';
import '../../core/models/goal.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/repository.dart';
import '../../core/services/snapshot.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/pickers.dart';
import '../utils/app_snack.dart';
import '../widgets/form_dialog.dart';

List<FieldSpec> goalFields(Snapshot s) => [
      const FText('title', 'Title', required: true),
      const FText('description', 'Description', multiline: true),
      FChoice('subjectId', 'Subject', subjectOptions(s), allowNone: true),
      const FNumber('currentLevel', 'Current knowledge level (0–10)'),
      const FNumber('targetLevel', 'Target knowledge level (0–10)'),
      const FDate('startDate', 'Start date', required: true),
      const FDate('deadline', 'Target deadline'),
      const FNumber('estHours', 'Estimated total effort', decimal: true, suffix: 'hours'),
      const FNumber('remHours', 'Estimated remaining effort', decimal: true, suffix: 'hours'),
      const FChoice('priority', 'Priority', {'1': 'Low', '2': 'Medium', '3': 'High'}),
      FChoice('status', 'Status', enumOptions(GoalStatus.values, (v) => v.label)),
      const FText('tags', 'Tags', hint: 'comma separated'),
      const FNumber('manualProgress', 'Manual progress override (%)'),
      const FText('criteria', 'Completion criteria', multiline: true),
      const FText('notes', 'Notes', multiline: true),
    ];

Map<String, Object?> goalInitial(Goal? g) => g == null
    ? {'startDate': dayOnly(DateTime.now()), 'priority': '2', 'status': 'notStarted', 'currentLevel': 0, 'targetLevel': 5}
    : {
        'title': g.title,
        'description': g.description,
        'subjectId': g.subjectId,
        'currentLevel': g.currentLevel,
        'targetLevel': g.targetLevel,
        'startDate': g.startDate,
        'deadline': g.deadline,
        'estHours': g.estimatedMinutes == null ? null : g.estimatedMinutes! / 60,
        'remHours': g.remainingMinutes == null ? null : g.remainingMinutes! / 60,
        'priority': '${g.priority}',
        'status': g.status.name,
        'tags': g.tags,
        'manualProgress': g.manualProgress,
        'criteria': g.criteria,
        'notes': g.notes,
      };

Future<void> editGoal(BuildContext context, WidgetRef ref, Snapshot s, {Goal? goal}) async {
  final v = await showForm(context,
      title: goal == null ? 'New goal' : 'Edit goal', fields: goalFields(s), initial: goalInitial(goal));
  if (v == null) return;
  final g = goal ?? Goal(title: v['title'] as String);
  g
    ..title = v['title'] as String
    ..description = (v['description'] as String?) ?? ''
    ..subjectId = v['subjectId'] as String?
    ..currentLevel = ((v['currentLevel'] as int?) ?? 0).clamp(0, 10)
    ..targetLevel = ((v['targetLevel'] as int?) ?? 5).clamp(0, 10)
    ..startDate = (v['startDate'] as DateTime?) ?? g.startDate
    ..deadline = v['deadline'] as DateTime?
    ..estimatedMinutes = v['estHours'] == null ? null : ((v['estHours'] as num) * 60).round()
    ..remainingMinutes = v['remHours'] == null ? null : ((v['remHours'] as num) * 60).round()
    ..priority = int.parse((v['priority'] as String?) ?? '2')
    ..status = GoalStatus.values.byName((v['status'] as String?) ?? 'notStarted')
    ..tags = (v['tags'] as String?) ?? ''
    ..manualProgress = (v['manualProgress'] as int?)?.clamp(0, 100)
    ..criteria = (v['criteria'] as String?) ?? ''
    ..notes = (v['notes'] as String?) ?? '';
  g.archived = g.status == GoalStatus.archived;
  await ref.read(repoProvider).saveGoal(g);
  if (context.mounted) toast(context, 'Goal saved');
}
