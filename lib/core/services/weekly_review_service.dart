import '../models/enums.dart';
import 'goal_analyzer.dart';
import 'snapshot.dart';
import '../utils/date_format.dart';

class WeeklyReviewData {
  WeeklyReviewData({
    required this.weekStart,
    required this.plannedMinutes,
    required this.actualMinutes,
    required this.completedSessions,
    required this.missedActivities,
    required this.onTrack,
    required this.atRisk,
    required this.milestonesDone,
    required this.revisionTopics,
    required this.priorities,
  });
  final DateTime weekStart;
  final int plannedMinutes, actualMinutes, completedSessions, missedActivities;
  final List<String> onTrack, atRisk, milestonesDone, revisionTopics, priorities;
}

class WeeklyReview {
  static WeeklyReviewData build(Snapshot s, DateTime weekStart) {
    final end = weekStart.add(const Duration(days: 7));
    bool inWeek(DateTime d) => !d.isBefore(weekStart) && d.isBefore(end);
    final acts = s.activities.where((a) => inWeek(a.start)).toList();
    final planned = acts.fold<int>(0, (a, x) => a + x.plannedMinutes);
    final sessions = s.sessions.where((x) => inWeek(fromMs(x.startedAt))).length;
    final missed = acts.where((a) => !a.done && a.start.isBefore(s.now) && a.status != 'skipped').length;
    final on = <String>[], risk = <String>[];
    final prios = <String>[];
    for (final g in s.goals.where((g) => g.status == GoalStatus.inProgress || g.status == GoalStatus.notStarted)) {
      final a = GoalAnalyzer.analyze(g, s);
      if (a.status == DeadlineStatus.onTrack) {
        on.add(g.title);
      } else if (a.status == DeadlineStatus.atRisk ||
          a.status == DeadlineStatus.unlikely ||
          a.status == DeadlineStatus.passed ||
          a.status == DeadlineStatus.adjustments) {
        risk.add(g.title);
        prios.add('Protect "${g.title}": ${a.nextAction}');
      }
    }
    final ms = s.milestones
        .where((m) => m.completedAt != null && inWeek(fromMs(m.completedAt!)))
        .map((m) => m.title)
        .toList();
    final rev = <String>{
      for (final t in s.topics.where((t) => t.revisionStatus == 'due')) t.name,
      for (final p in s.problems.where((p) => p.revisionRequired || p.result == ProblemResult.needsRevision))
        p.title,
    }.take(8).toList();
    if (rev.isNotEmpty) prios.add('Revise: ${rev.take(3).join(', ')}');
    if (prios.isEmpty) prios.add('Keep your current rhythm and log each session.');
    return WeeklyReviewData(
      weekStart: weekStart,
      plannedMinutes: planned,
      actualMinutes: s.minutesBetween(weekStart, end),
      completedSessions: sessions,
      missedActivities: missed,
      onTrack: on,
      atRisk: risk,
      milestonesDone: ms,
      revisionTopics: rev,
      priorities: prios,
    );
  }
}
