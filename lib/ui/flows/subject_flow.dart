import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors/app_colors.dart';
import '../../core/models/enums.dart';
import '../../core/models/subject.dart';
import '../../core/models/topic.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/repository.dart';
import '../../core/services/snapshot.dart';
import '../widgets/form_dialog.dart';

Future<void> editSubject(BuildContext context, WidgetRef ref, {Subject? subject}) async {
  final v = await showForm(context,
      title: subject == null ? 'New subject' : 'Edit subject',
      fields: [
        const FText('name', 'Name', required: true),
        const FText('description', 'Description', multiline: true),
        const FText('category', 'Category'),
        FChoice('icon', 'Icon', {for (final k in subjectIcons.keys) k: k[0].toUpperCase() + k.substring(1)}),
        FChoice('color', 'Colour', {
          for (var i = 0; i < subjectColors.length; i++) '${subjectColors[i]}': 'Colour ${i + 1}'
        }),
        FChoice('difficulty', 'Difficulty', {for (final d in difficulties) d: d}),
        const FNumber('target', 'Target study hours', decimal: true, suffix: 'hours'),
      ],
      initial: {
        'name': subject?.name,
        'description': subject?.description,
        'category': subject?.category ?? 'General',
        'icon': subject?.icon ?? 'book',
        'color': '${subject?.color ?? subjectColors.first}',
        'difficulty': subject?.difficulty ?? 'Beginner',
        'target': subject?.targetHours,
      });
  if (v == null) return;
  final s = subject ?? Subject(name: v['name'] as String);
  s
    ..name = v['name'] as String
    ..description = (v['description'] as String?) ?? ''
    ..category = ((v['category'] as String?)?.isEmpty ?? true) ? 'General' : v['category'] as String
    ..icon = (v['icon'] as String?) ?? 'book'
    ..color = int.parse((v['color'] as String?) ?? '${subjectColors.first}')
    ..difficulty = (v['difficulty'] as String?) ?? 'Beginner'
    ..targetHours = ((v['target'] as num?) ?? 0).toDouble();
  await ref.read(repoProvider).saveSubject(s);
}

Future<void> editTopic(BuildContext context, WidgetRef ref, Snapshot s, String subjectId, {Topic? topic}) async {
  final others = {for (final t in s.topics.where((t) => t.subjectId == subjectId && t.id != topic?.id)) t.id: t.name};
  final v = await showForm(context,
      title: topic == null ? 'New topic' : 'Edit topic',
      fields: [
        const FText('name', 'Name', required: true),
        const FText('description', 'Description', multiline: true),
        const FNumber('minutes', 'Estimated effort', suffix: 'minutes'),
        FChoice('difficulty', 'Difficulty', {for (final d in difficulties) d: d}),
        const FChoice('status', 'Status', {'todo': 'To do', 'learning': 'Learning', 'done': 'Done'}),
        const FChoice('revision', 'Revision', {'none': 'None', 'due': 'Revision due', 'done': 'Revised'}),
        FChoice('prereq', 'Prerequisite', others, allowNone: true),
      ],
      initial: {
        'name': topic?.name,
        'description': topic?.description,
        'minutes': topic?.estimatedMinutes ?? 60,
        'difficulty': topic?.difficulty ?? 'Beginner',
        'status': topic?.status ?? 'todo',
        'revision': topic?.revisionStatus ?? 'none',
        'prereq': topic?.prerequisiteId,
      });
  if (v == null) return;
  final t = topic ?? Topic(subjectId: subjectId, name: v['name'] as String);
  t
    ..name = v['name'] as String
    ..description = (v['description'] as String?) ?? ''
    ..estimatedMinutes = (v['minutes'] as int?) ?? 60
    ..difficulty = (v['difficulty'] as String?) ?? 'Beginner'
    ..status = (v['status'] as String?) ?? 'todo'
    ..revisionStatus = (v['revision'] as String?) ?? 'none'
    ..prerequisiteId = v['prereq'] as String?;
  await ref.read(repoProvider).saveTopic(t);
}
