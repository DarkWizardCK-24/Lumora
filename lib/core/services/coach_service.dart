import '../models/enums.dart';
import 'goal_analyzer.dart';
import 'snapshot.dart';
import 'streak_engine.dart';
import '../utils/date_format.dart';
import '../utils/format.dart';

enum TipSeverity { info, positive, warning, critical }

class Tip {
  Tip(this.key, this.title, this.why, this.recommendation, this.severity,
      {this.actionLabel, this.route, required this.fingerprint});
  final String key, title, why, recommendation, fingerprint;
  final TipSeverity severity;
  final String? actionLabel, route;
}

class CoachService {
  /// Rule-based, explainable tips. [dismissed] maps tip key -> fingerprint at
  /// dismissal; a tip stays hidden until its underlying data changes.
  static List<Tip> tips(Snapshot s, Map<String, String> dismissed) {
    final out = <Tip>[];
    final weekStart = s.today.subtract(Duration(days: s.today.weekday - 1));
    final weekActs = s.activities.where((a) =>
        !a.start.isBefore(weekStart) &&
        a.start.isBefore(weekStart.add(const Duration(days: 7))) &&
        a.start.isBefore(s.now) &&
        a.status != 'skipped');
    final planned = weekActs.length;
    final doneCount = weekActs.where((a) => a.done).length;
    if (planned >= 2 && doneCount / planned < 0.6) {
      out.add(Tip(
          'behind-week',
          'You are behind schedule',
          'You completed $doneCount of $planned planned sessions this week.',
          'Your current plan needs adjustment to protect the deadline.',
          TipSeverity.warning,
          actionLabel: 'Review goals',
          route: '/goals',
          fingerprint: '$doneCount/$planned'));
    } else if (planned >= 2 && doneCount == planned) {
      out.add(Tip(
          'on-plan',
          'Right on plan',
          'All $planned sessions planned so far this week are done.',
          'Continue with the current workload and review your next milestone.',
          TipSeverity.positive,
          actionLabel: 'View milestones',
          route: '/milestones',
          fingerprint: '$doneCount/$planned'));
    }

    for (final g in s.goals.where((g) => g.status == GoalStatus.inProgress || g.status == GoalStatus.notStarted)) {
      if (g.archived) continue;
      final a = GoalAnalyzer.analyze(g, s);
      if (a.remainingMinutes != null && a.gapMinutes > 0 && a.status != DeadlineStatus.passed) {
        out.add(Tip(
            'capacity-${g.id}',
            '"${g.title}" needs more time than available',
            'Estimated ${fmtDuration(a.remainingMinutes!)} remaining, but available capacity is ${fmtDuration(a.capacityMinutes)}.',
            'Consider reducing the scope or changing the deadline.',
            a.status == DeadlineStatus.unlikely ? TipSeverity.critical : TipSeverity.warning,
            actionLabel: 'Analyze goal',
            route: '/analysis',
            fingerprint: '${a.remainingMinutes}/${a.capacityMinutes}'));
      }
      if (a.status == DeadlineStatus.passed) {
        out.add(Tip('passed-${g.id}', '"${g.title}" is past its deadline',
            'The target date has passed and the goal is not completed.',
            'Review the plan and choose a new realistic date — nothing is changed automatically.',
            TipSeverity.critical,
            actionLabel: 'Open goal', route: '/goals', fingerprint: dateKey(g.deadline!)));
      }
      final recent = s.goalMinutes(g.id, since: s.today.subtract(const Duration(days: 10)));
      if (recent == 0 && g.status == GoalStatus.inProgress) {
        out.add(Tip(
            'inactive-${g.id}',
            '"${g.title}" has gone quiet',
            'No study time was logged against it in the last 10 days.',
            'Start with one small task that fits your available time.',
            TipSeverity.info,
            actionLabel: 'Start session',
            route: '/sessions',
            fingerprint: dateKey(s.today)));
      }
    }

    final due = s.problems.where((p) =>
        p.revisionRequired ||
        p.result == ProblemResult.needsRevision ||
        (p.nextReview != null && !p.nextReview!.isAfter(s.today))).length;
    if (due >= 2) {
      out.add(Tip(
          'revision',
          'Revision needed',
          '$due coding problems are waiting in your revision queue.',
          'Schedule a short review before moving to the next topic.',
          TipSeverity.warning,
          actionLabel: 'Open practice',
          route: '/coding',
          fingerprint: '$due'));
    }

    final cal = GoalAnalyzer.calibration(s);
    if (cal > 1.2) {
      out.add(Tip(
          'estimates',
          'Your estimates run low',
          'Completed goals took about ${((cal - 1) * 100).round()}% longer than planned.',
          'Include additional time for practice and revision in your next plan.',
          TipSeverity.info,
          fingerprint: cal.toStringAsFixed(2)));
    }
    final streak = StreakEngine.compute(s);
    if (streak.current >= 3) {
      out.add(Tip('streak-${streak.current ~/ 7}', '${streak.current}-day streak',
          'You studied on ${streak.current} days in a row.',
          'Keep it alive with a short session today.', TipSeverity.positive,
          fingerprint: '${streak.current}'));
    }
    return out.where((t) => dismissed[t.key] != t.fingerprint).toList()
      ..sort((a, b) => b.severity.index.compareTo(a.severity.index));
  }
}
