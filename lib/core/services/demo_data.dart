import '../models/activity.dart';
import '../models/coding_problem.dart';
import '../models/enums.dart';
import '../models/goal.dart';
import '../models/milestone.dart';
import '../models/note.dart';
import '../models/study_session.dart';
import '../utils/date_format.dart';
import 'repository.dart';
import 'seed_data.dart';

/// Developer-only sample data, used to capture README screenshots.
/// Enabled with the LUMORA_SEED_DEMO=1 environment variable and only when the
/// database is empty — it never runs for normal users.
Future<void> seedDemoData(Repository repo) async {
  if ((await repo.subjects()).isNotEmpty) return;
  await addStarterSubjects(repo);
  final subjects = {for (final s in await repo.subjects()) s.name: s};
  final today = dayOnly(DateTime.now());
  DateTime inDays(int d) => today.add(Duration(days: d));

  final python = Goal(
      title: 'Master Python fundamentals',
      description: 'Loops, functions, OOP, files and exceptions.',
      subjectId: subjects['Python']!.id,
      deadline: inDays(24),
      estimatedMinutes: 30 * 60,
      remainingMinutes: 14 * 60,
      priority: 3,
      status: GoalStatus.inProgress,
      startDate: inDays(-18),
      tags: 'python,basics');
  final dsa = Goal(
      title: 'Solve 100 DSA problems',
      subjectId: subjects['Data Structures & Algorithms']!.id,
      deadline: inDays(12),
      estimatedMinutes: 60 * 60,
      remainingMinutes: 38 * 60,
      priority: 2,
      status: GoalStatus.inProgress,
      startDate: inDays(-20),
      tags: 'dsa,interview');
  final sql = Goal(
      title: 'SQL & database fundamentals',
      subjectId: subjects['SQL & Databases']!.id,
      deadline: inDays(45),
      estimatedMinutes: 20 * 60,
      priority: 2,
      status: GoalStatus.notStarted,
      startDate: inDays(-2));
  final flutter = Goal(
      title: 'Ship a Flutter portfolio app',
      subjectId: subjects['Flutter']!.id,
      estimatedMinutes: 40 * 60,
      remainingMinutes: 40 * 60,
      priority: 1,
      status: GoalStatus.paused,
      startDate: inDays(-30));
  for (final g in [python, dsa, sql, flutter]) {
    await repo.saveGoal(g);
  }

  final pyTopics = await repo.topics(subjectId: subjects['Python']!.id);
  for (var i = 0; i < pyTopics.length; i++) {
    pyTopics[i]
      ..goalId = python.id
      ..status = i < 3 ? 'done' : 'todo';
    await repo.saveTopic(pyTopics[i]);
  }
  await repo.saveMilestone(Milestone(goalId: python.id, title: 'Finish loops & functions', dueDate: inDays(-3), completedAt: nowMs() - 3 * 86400000));
  await repo.saveMilestone(Milestone(goalId: python.id, title: 'Build a CLI project with OOP', dueDate: inDays(10), estimatedMinutes: 300));
  await repo.saveMilestone(Milestone(goalId: dsa.id, title: 'Arrays & strings: 30 problems', dueDate: inDays(5), estimatedMinutes: 600));
  await repo.saveMilestone(Milestone(goalId: dsa.id, title: 'Trees & graphs mock test', dueDate: inDays(11), estimatedMinutes: 240));

  // Three weeks of study sessions.
  final pattern = [75, 45, 0, 90, 60, 120, 30, 50, 80, 0, 65, 100, 40, 55, 70, 0, 85, 60, 95, 45, 35];
  for (var i = 0; i < pattern.length; i++) {
    final mins = pattern[i];
    if (mins == 0) continue;
    final day = inDays(-(pattern.length - 1 - i));
    final start = DateTime(day.year, day.month, day.day, 18).millisecondsSinceEpoch;
    final useDsa = i % 3 == 0;
    await repo.saveSession(StudySession(
      subjectId: (useDsa ? subjects['Data Structures & Algorithms'] : subjects['Python'])!.id,
      goalId: (useDsa ? dsa : python).id,
      type: useDsa ? SessionType.codingPractice : SessionType.learning,
      startedAt: start,
      endedAt: start + mins * 60000,
      activeSeconds: mins * 60,
      status: SessionStatus.completed,
      notes: useDsa ? 'Two-pointer patterns' : 'Practised functions',
    ));
  }

  const probs = [
    ('Two Sum', 'LeetCode', 'Easy', ProblemResult.solved),
    ('Valid Parentheses', 'LeetCode', 'Easy', ProblemResult.solved),
    ('Merge Intervals', 'LeetCode', 'Medium', ProblemResult.needsRevision),
    ('Longest Substring Without Repeating', 'LeetCode', 'Medium', ProblemResult.solved),
    ('Word Ladder', 'LeetCode', 'Hard', ProblemResult.unsolved),
    ('Binary Search', 'GeeksforGeeks', 'Easy', ProblemResult.solved),
  ];
  for (var i = 0; i < probs.length; i++) {
    final p = probs[i];
    await repo.saveProblem(CodingProblem(
      title: p.$1,
      platform: p.$2,
      difficulty: p.$3,
      result: p.$4,
      attemptedAt: DateTime.now().subtract(Duration(days: i * 2)).millisecondsSinceEpoch,
      minutes: 15 + i * 7,
      subjectId: subjects['Data Structures & Algorithms']!.id,
      revisionRequired: p.$4 == ProblemResult.needsRevision,
    ));
  }

  await repo.saveNote(Note(
      title: 'Python: list comprehensions',
      body: '# List comprehensions\n\n- Faster and clearer than loops for simple maps\n- `[x*x for x in range(5)]`\n\n**Remember:** keep them readable.',
      subjectId: subjects['Python']!.id,
      tags: 'python,cheatsheet',
      favorite: true));
  await repo.saveNote(Note(title: 'Big-O quick reference', body: '- O(1) hash lookup\n- O(log n) binary search\n- O(n log n) sorting', tags: 'dsa'));

  final base = DateTime(today.year, today.month, today.day, 18);
  for (final a in [
    ('Learn: File handling', ActivityKind.study, 0, 45, false),
    ('Practice: File handling', ActivityKind.practice, 0, 30, false),
    ('Revise recent topics', ActivityKind.revision, 1, 20, false),
    ('Learn: Exceptions', ActivityKind.study, 2, 45, false),
    ('Assess: CLI project', ActivityKind.assessment, 5, 30, false),
  ]) {
    final start = base.add(Duration(days: a.$3));
    await repo.saveActivity(Activity(
      title: a.$1,
      kind: a.$2,
      goalId: python.id,
      subjectId: subjects['Python']!.id,
      plannedStart: start.millisecondsSinceEpoch,
      plannedEnd: start.add(Duration(minutes: a.$4)).millisecondsSinceEpoch,
      plannedMinutes: a.$4,
      generated: true,
    ));
  }
}
