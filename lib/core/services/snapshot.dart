import '../models/activity.dart';
import '../models/coding_problem.dart';
import '../models/flashcard.dart';
import '../models/goal.dart';
import '../models/milestone.dart';
import '../models/study_session.dart';
import '../models/subject.dart';
import '../models/topic.dart';
import '../utils/date_format.dart';

/// Immutable view of everything the analysers need. Built from SQLite.
class Snapshot {
  Snapshot({
    this.goals = const [],
    this.milestones = const [],
    this.sessions = const [],
    this.activities = const [],
    this.problems = const [],
    this.topics = const [],
    this.subjects = const [],
    this.cards = const [],
    this.cardReviews = const [],
    this.attempts = const [],
    Map<int, int>? availability,
    DateTime? now,
    this.minQualifyingMinutes = 5,
    this.dailyTargetMinutes = 60,
    this.studyHour = 18,
    this.streakFreezeEnabled = false,
  })  : availability = availability ?? {for (var d = 1; d <= 7; d++) d: d <= 5 ? 60 : 90},
        now = now ?? DateTime.now();
  final List<Goal> goals;
  final List<Milestone> milestones;
  final List<StudySession> sessions; // completed only
  final List<Activity> activities;
  final List<CodingProblem> problems;
  final List<Topic> topics;
  final List<Subject> subjects;
  final List<Flashcard> cards;
  final List<CardReview> cardReviews;
  final List<ProblemAttempt> attempts;
  final Map<int, int> availability; // weekday(1..7) -> minutes
  final DateTime now;
  final int minQualifyingMinutes, dailyTargetMinutes, studyHour;
  final bool streakFreezeEnabled;

  DateTime get today => dayOnly(now);

  int get cardsDue => cards.where((c) => c.isDue(today)).length;

  int goalMinutes(String goalId, {DateTime? since}) {
    var s = 0;
    for (final x in sessions) {
      if (x.goalId == goalId && (since == null || fromMs(x.startedAt).isAfter(since))) {
        s += x.activeSeconds ~/ 60;
      }
    }
    return s;
  }

  /// Practice minutes that are NOT already inside a linked study session,
  /// so combined totals never count the same time twice.
  int get unlinkedProblemMinutes =>
      problems.where((p) => p.sessionId == null).fold(0, (a, p) => a + p.minutes);

  int minutesOn(DateTime day) {
    final k = dateKey(day);
    var m = 0;
    for (final s in sessions) {
      if (dateKey(fromMs(s.startedAt)) == k) m += s.activeSeconds ~/ 60;
    }
    for (final p in problems) {
      if (p.sessionId == null && dateKey(fromMs(p.attemptedAt)) == k) m += p.minutes;
    }
    return m;
  }

  int get totalMinutes =>
      sessions.fold(0, (a, s) => a + s.activeSeconds ~/ 60) + unlinkedProblemMinutes;

  int minutesBetween(DateTime from, DateTime toExclusive) {
    var m = 0;
    for (var d = dayOnly(from); d.isBefore(toExclusive); d = d.add(const Duration(days: 1))) {
      m += minutesOn(d);
    }
    return m;
  }
}
