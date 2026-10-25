import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/milestone.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/repository.dart';
import '../../core/services/snapshot.dart';
import '../utils/app_snack.dart';
import '../widgets/form_dialog.dart';

Future<void> editMilestone(BuildContext context, WidgetRef ref, Snapshot s,
    {Milestone? milestone, String? goalId}) async {
  final goals = {for (final g in s.goals.where((g) => !g.archived)) g.id: g.title};
  if (goals.isEmpty) {
    toast(context, 'Create a goal first — milestones belong to a goal.', error: true);
    return;
  }
  final v = await showForm(context,
      title: milestone == null ? 'New milestone' : 'Edit milestone',
      fields: [
        const FText('title', 'Title', required: true),
        FChoice('goalId', 'Goal', goals),
        const FDate('dueDate', 'Due date'),
        const FNumber('hours', 'Estimated effort', decimal: true, suffix: 'hours'),
        const FText('criteria', 'Measurable criteria', multiline: true, hint: 'e.g. Solve 10 array problems'),
        const FText('description', 'Description', multiline: true),
      ],
      initial: {
        'title': milestone?.title,
        'goalId': milestone?.goalId ?? goalId ?? goals.keys.first,
        'dueDate': milestone?.dueDate,
        'hours': milestone == null || milestone.estimatedMinutes == 0 ? null : milestone.estimatedMinutes / 60,
        'criteria': milestone?.criteria,
        'description': milestone?.description,
      });
  if (v == null) return;
  final m = milestone ?? Milestone(goalId: v['goalId'] as String, title: v['title'] as String);
  m
    ..title = v['title'] as String
    ..goalId = (v['goalId'] as String?) ?? m.goalId
    ..dueDate = v['dueDate'] as DateTime?
    ..estimatedMinutes = v['hours'] == null ? 0 : ((v['hours'] as num) * 60).round()
    ..criteria = (v['criteria'] as String?) ?? ''
    ..description = (v['description'] as String?) ?? '';
  await ref.read(repoProvider).saveMilestone(m);
}
