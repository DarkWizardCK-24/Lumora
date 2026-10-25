import '../models/enums.dart';
import 'snapshot.dart';
import 'streak_engine.dart';

class AchievementDef {
  const AchievementDef(this.code, this.title, this.description);
  final String code, title, description;
}

const achievementDefs = [
  AchievementDef('first-session', 'First step', 'Complete your first study session'),
  AchievementDef('first-goal', 'Goal getter', 'Complete your first learning goal'),
  AchievementDef('streak-7', 'Seven-day streak', 'Study seven days in a row'),
  AchievementDef('hours-10', 'Ten hours in', 'Log 10 hours of study'),
  AchievementDef('solved-25', 'Problem solver', 'Solve 25 coding problems'),
  AchievementDef('subject-done', 'Subject mastered', 'Finish every topic in a subject'),
];

class AchievementEngine {
  static Set<String> earned(Snapshot s) {
    final out = <String>{};
    if (s.sessions.isNotEmpty) out.add('first-session');
    if (s.goals.any((g) => g.status == GoalStatus.completed)) out.add('first-goal');
    if (StreakEngine.compute(s).longest >= 7) out.add('streak-7');
    if (s.totalMinutes >= 600) out.add('hours-10');
    if (s.problems.where((p) => p.result == ProblemResult.solved).length >= 25) out.add('solved-25');
    for (final sub in s.subjects) {
      final ts = s.topics.where((t) => t.subjectId == sub.id).toList();
      if (ts.isNotEmpty && ts.every((t) => t.status == 'done')) out.add('subject-done');
    }
    return out;
  }
}
