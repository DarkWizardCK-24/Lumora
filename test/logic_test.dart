import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/core/models/activity.dart';
import 'package:lumora/core/models/coding_problem.dart';
import 'package:lumora/core/models/enums.dart';
import 'package:lumora/core/models/goal.dart';
import 'package:lumora/core/models/study_session.dart';
import 'package:lumora/core/models/topic.dart';
import 'package:lumora/core/services/coach_service.dart';
import 'package:lumora/core/services/goal_analyzer.dart';
import 'package:lumora/core/services/schedule_generator.dart';
import 'package:lumora/core/services/snapshot.dart';
import 'package:lumora/core/services/streak_engine.dart';
import 'package:lumora/core/utils/date_format.dart';

final _now = DateTime(2026, 10, 24, 12);

StudySession _session(DateTime day, int minutes, {String? goalId}) {
  final start = DateTime(day.year, day.month, day.day, 18).millisecondsSinceEpoch;
  return StudySession(
      goalId: goalId,
      startedAt: start,
      endedAt: start + minutes * 60000,
      activeSeconds: minutes * 60,
      status: SessionStatus.completed);
}

void main() {
  group('study duration', () {
    test('subtracts pauses and clamps to the session window', () {
      final pauses = [
        Pause(sessionId: 's', startedAt: 10 * 60000, endedAt: 20 * 60000),
        Pause(sessionId: 's', startedAt: 50 * 60000), // still open at the end
      ];
      // 60 minutes elapsed, 10 + 10 paused => 40 minutes active.
      expect(StudySession.computeActiveSeconds(0, 60 * 60000, pauses), 40 * 60);
    });
    test('never negative', () {
      expect(StudySession.computeActiveSeconds(1000, 500, const []), 0);
    });
  });

  group('streaks', () {
    test('counts consecutive days and tolerates today being pending', () {
      final today = dayOnly(_now);
      final s = Snapshot(
        now: _now,
        sessions: [
          for (var i = 1; i <= 3; i++) _session(today.subtract(Duration(days: i)), 30),
          _session(today.subtract(const Duration(days: 6)), 30),
          _session(today.subtract(const Duration(days: 7)), 30),
        ],
      );
      final st = StreakEngine.compute(s);
      expect(st.current, 3);
      expect(st.longest, 3);
    });
    test('sessions below the qualifying minutes do not count', () {
      final s = Snapshot(now: _now, sessions: [_session(dayOnly(_now), 2)], minQualifyingMinutes: 5);
      expect(StreakEngine.compute(s).current, 0);
    });
    test('solved problems qualify a day; deleting data recomputes', () {
      final p = CodingProblem(title: 'x', attemptedAt: _now.millisecondsSinceEpoch, result: ProblemResult.solved);
      expect(StreakEngine.compute(Snapshot(now: _now, problems: [p])).current, 1);
      expect(StreakEngine.compute(Snapshot(now: _now)).current, 0);
    });
  });

  group('combined totals', () {
    test('practice linked to a session is not double counted', () {
      final sess = _session(dayOnly(_now), 60);
      final linked = CodingProblem(title: 'a', attemptedAt: sess.startedAt, minutes: 30, sessionId: sess.id);
      final loose = CodingProblem(title: 'b', attemptedAt: sess.startedAt, minutes: 15);
      final s = Snapshot(now: _now, sessions: [sess], problems: [linked, loose]);
      expect(s.totalMinutes, 75); // 60 session + 15 unlinked, not 105
    });
  });

  group('goal analysis', () {
    test('asks for an estimate instead of inventing one', () {
      final g = Goal(title: 'Learn', deadline: DateTime(2026, 11, 20));
      final a = GoalAnalyzer.analyze(g, Snapshot(now: _now, goals: [g]));
      expect(a.status, DeadlineStatus.needsEstimate);
      expect(a.remainingMinutes, isNull);
      expect(a.confidence, Confidence.low);
    });
    test('on track when capacity comfortably exceeds remaining effort', () {
      final g = Goal(title: 'Learn', deadline: DateTime(2026, 12, 24), remainingMinutes: 300, status: GoalStatus.inProgress);
      final a = GoalAnalyzer.analyze(g, Snapshot(now: _now, goals: [g]));
      expect(a.status, DeadlineStatus.onTrack);
      expect(a.gapMinutes, 0);
    });
    test('flags an infeasible deadline and offers alternatives', () {
      final g = Goal(title: 'Big', deadline: DateTime(2026, 10, 30), remainingMinutes: 60 * 40, status: GoalStatus.inProgress);
      final a = GoalAnalyzer.analyze(g, Snapshot(now: _now, goals: [g]));
      expect(a.status, DeadlineStatus.unlikely);
      expect(a.gapMinutes, greaterThan(0));
      expect(a.alternatives, isNotEmpty);
    });
    test('passed and completed statuses', () {
      final late = Goal(title: 'Late', deadline: DateTime(2026, 10, 1), remainingMinutes: 60);
      expect(GoalAnalyzer.analyze(late, Snapshot(now: _now, goals: [late])).status, DeadlineStatus.passed);
      final done = Goal(title: 'Done', status: GoalStatus.completed);
      expect(GoalAnalyzer.analyze(done, Snapshot(now: _now, goals: [done])).status, DeadlineStatus.completed);
    });
    test('manual progress is never overridden by automatic calculation', () {
      final g = Goal(title: 'Manual', manualProgress: 40, remainingMinutes: 100);
      expect(GoalAnalyzer.progressOf(g, Snapshot(now: _now, goals: [g])), 0.4);
    });
    test('time alone is not mastery', () {
      final g = Goal(title: 'Time only', remainingMinutes: 100);
      final s = Snapshot(now: _now, goals: [g], sessions: [_session(dayOnly(_now), 120, goalId: g.id)]);
      expect(GoalAnalyzer.progressOf(g, s), 0);
    });
    test('calibration is damped by sample size and clamped', () {
      final done = Goal(title: 'Done', status: GoalStatus.completed, estimatedMinutes: 60, subjectId: 's');
      final s = Snapshot(now: _now, goals: [done], sessions: [_session(dayOnly(_now), 600, goalId: done.id)]);
      final c = GoalAnalyzer.calibration(s);
      expect(c, greaterThan(1));
      expect(c, lessThanOrEqualTo(1.6));
      expect(GoalAnalyzer.calibration(Snapshot(now: _now)), 1);
    });
  });

  group('schedule generation', () {
    test('never exceeds availability and reports what does not fit', () {
      final g = Goal(title: 'Big', deadline: DateTime(2026, 10, 27), remainingMinutes: 60 * 30, status: GoalStatus.inProgress);
      final s = Snapshot(now: _now, goals: [g]);
      final plan = ScheduleGenerator.generate(g, s);
      final perDay = <String, int>{};
      for (final a in plan.activities) {
        final k = dateKey(a.start);
        perDay[k] = (perDay[k] ?? 0) + a.plannedMinutes;
      }
      for (final e in perDay.entries) {
        final wd = parseDate(e.key).weekday;
        expect(e.value, lessThanOrEqualTo((s.availability[wd]! * 0.9).floor()));
      }
      expect(plan.fits, isFalse);
      expect(plan.unscheduledMinutes, greaterThan(0));
    });
    test('keeps completed activities when replanning', () {
      final g = Goal(title: 'Plan', deadline: DateTime(2026, 11, 20), remainingMinutes: 240, status: GoalStatus.inProgress);
      final doneAct = Activity(
          title: 'Done earlier',
          goalId: g.id,
          generated: true,
          status: 'done',
          plannedStart: DateTime(2026, 10, 20, 18).millisecondsSinceEpoch,
          plannedEnd: DateTime(2026, 10, 20, 19).millisecondsSinceEpoch);
      final futureAct = Activity(
          title: 'Future generated',
          goalId: g.id,
          generated: true,
          plannedStart: DateTime(2026, 10, 26, 18).millisecondsSinceEpoch,
          plannedEnd: DateTime(2026, 10, 26, 19).millisecondsSinceEpoch);
      final plan = ScheduleGenerator.generate(g, Snapshot(now: _now, goals: [g], activities: [doneAct, futureAct]));
      expect(plan.removedCount, 1); // only the unfinished future one is replaced
      expect(plan.keptCount, 1);
    });
    test('uses user topics first', () {
      final g = Goal(title: 'Topics', deadline: DateTime(2026, 11, 30), status: GoalStatus.inProgress);
      final t = Topic(subjectId: 's', goalId: g.id, name: 'Recursion', estimatedMinutes: 90);
      final plan = ScheduleGenerator.generate(g, Snapshot(now: _now, goals: [g], topics: [t]));
      expect(plan.activities.any((a) => a.title.contains('Recursion')), isTrue);
    });
  });

  group('coach tips', () {
    test('explain why, and stay dismissed until data changes', () {
      final g = Goal(title: 'Big', deadline: DateTime(2026, 10, 30), remainingMinutes: 60 * 40, status: GoalStatus.inProgress);
      final s = Snapshot(now: _now, goals: [g]);
      final tips = CoachService.tips(s, const {});
      final cap = tips.firstWhere((t) => t.key == 'capacity-${g.id}');
      expect(cap.why, isNotEmpty);
      expect(cap.recommendation, isNotEmpty);
      expect(CoachService.tips(s, {cap.key: cap.fingerprint}).any((t) => t.key == cap.key), isFalse);
      expect(CoachService.tips(s, {cap.key: 'stale'}).any((t) => t.key == cap.key), isTrue);
    });
  });
}
