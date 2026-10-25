import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/coding_problem.dart';
import '../../core/models/enums.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/repository.dart';
import '../../core/services/snapshot.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/pickers.dart';
import '../widgets/form_dialog.dart';

/// Quick "resurface in N days" choices shared by the editor and the revision queue.
const revisitChoices = [1, 3, 7, 14, 30];

Future<void> editProblem(BuildContext context, WidgetRef ref, Snapshot s, {CodingProblem? problem}) async {
  final v = await showForm(context,
      title: problem == null ? 'Log coding practice' : 'Edit problem',
      fields: [
        const FText('title', 'Problem title', required: true),
        FChoice('platform', 'Platform', {for (final p in platforms) p: p}),
        const FText('url', 'Problem URL', keyboard: TextInputType.url),
        FChoice('subjectId', 'Subject', subjectOptions(s), allowNone: true),
        FChoice('difficulty', 'Difficulty', {for (final d in problemDifficulties) d: d}),
        const FText('language', 'Language'),
        const FDateTime('attemptedAt', 'Date attempted'),
        FChoice('result', 'Result', enumOptions(ProblemResult.values, (e) => e.label)),
        const FNumber('minutes', 'Time spent', suffix: 'minutes'),
        const FNumber('attempts', 'Attempts'),
        FChoice('pattern', 'Pattern', {for (final x in problemPatterns) x: x}, allowNone: true),
        const FText('approach', 'Approach', multiline: true),
        const FText('snippet', 'Solution code (saved to your snippet vault)', multiline: true),
        const FText('notes', 'Solution notes', multiline: true),
        const FSwitch('revision', 'Revision required'),
        FChoice('revisitIn', 'Resurface this problem', {for (final d in revisitChoices) '$d': 'In $d days'}, allowNone: true),
        const FDate('nextReview', 'Or pick a review date'),
      ],
      initial: {
        'title': problem?.title,
        'platform': problem?.platform ?? 'LeetCode',
        'url': problem?.url,
        'subjectId': problem?.subjectId,
        'difficulty': problem?.difficulty ?? 'Easy',
        'language': problem?.language ?? 'Python',
        'attemptedAt': problem == null ? DateTime.now() : fromMs(problem.attemptedAt),
        'result': problem?.result.name ?? 'solved',
        'minutes': problem?.minutes ?? 20,
        'attempts': problem?.attempts ?? 1,
        'approach': problem?.approach,
        'pattern': (problem?.pattern.isEmpty ?? true) ? null : problem!.pattern,
        'snippet': problem?.snippet,
        'notes': problem?.notes,
        'revision': problem?.revisionRequired ?? false,
        'nextReview': problem?.nextReview,
      });
  if (v == null) return;
  final p = problem ?? CodingProblem(title: v['title'] as String, attemptedAt: nowMs());
  p
    ..title = v['title'] as String
    ..platform = (v['platform'] as String?) ?? 'Custom'
    ..url = (v['url'] as String?) ?? ''
    ..subjectId = v['subjectId'] as String?
    ..difficulty = (v['difficulty'] as String?) ?? 'Easy'
    ..language = (v['language'] as String?) ?? ''
    ..attemptedAt = ((v['attemptedAt'] as DateTime?) ?? DateTime.now()).millisecondsSinceEpoch
    ..result = ProblemResult.values.byName((v['result'] as String?) ?? 'attempted')
    ..minutes = (v['minutes'] as int?) ?? 0
    ..attempts = ((v['attempts'] as int?) ?? 1).clamp(1, 999)
    ..approach = (v['approach'] as String?) ?? ''
    ..pattern = (v['pattern'] as String?) ?? ''
    ..snippet = ((v['snippet'] as String?) ?? '').trimRight()
    ..notes = (v['notes'] as String?) ?? ''
    ..revisionRequired = (v['revision'] as bool?) ?? false
    ..nextReview = v['nextReview'] as DateTime?;
  final revisit = int.tryParse((v['revisitIn'] as String?) ?? '');
  if (revisit != null) {
    final today = dayOnly(DateTime.now());
    p.nextReview = DateTime(today.year, today.month, today.day + revisit);
  }
  await ref.read(repoProvider).saveProblem(p);
}
