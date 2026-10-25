import 'dart:math' as math;
import '../models/enums.dart';
import '../models/study_session.dart';
import '../utils/date_format.dart';
import 'snapshot.dart';

/// When the user studies and when they focus best.
class HourInsight {
  const HourInsight(this.minutes, this.bestHour, this.sharpestHour, this.sharpestRating, this.sessions);

  /// Study minutes per hour of day (0..23).
  final List<double> minutes;

  /// The hour with the most study time, or null when there is no data.
  final int? bestHour;

  /// The hour with the highest average self-rated focus (needs 3+ rated sessions).
  final int? sharpestHour;
  final double? sharpestRating;
  final int sessions;
}

class SubjectFocus {
  const SubjectFocus(this.subjectId, this.name, this.color, this.minutes, this.sessions, this.avgRating);
  final String? subjectId;
  final String name;
  final int color, minutes, sessions;
  final double? avgRating;
  double get avgSessionMinutes => sessions == 0 ? 0 : minutes / sessions;
}

enum BurnoutLevel { none, watch, high }

class BurnoutReport {
  const BurnoutReport(this.level, this.reasons, this.advice, this.last7Minutes, this.baselineWeekMinutes);
  final BurnoutLevel level;
  final List<String> reasons;
  final String advice;
  final int last7Minutes, baselineWeekMinutes;
}

class YearReview {
  const YearReview({
    required this.year,
    required this.minutes,
    required this.sessions,
    required this.activeDays,
    required this.longestStreak,
    required this.monthMinutes,
    required this.topSubject,
    required this.topSubjectMinutes,
    required this.bestWeekday,
    required this.longestSessionMinutes,
    required this.problemsSolved,
    required this.hardSolved,
    required this.cardsReviewed,
    required this.goalsCompleted,
    required this.avgRating,
    required this.bestHour,
  });
  final int year, minutes, sessions, activeDays, longestStreak;
  final List<int> monthMinutes; // 12 entries, Jan..Dec
  final String? topSubject;
  final int topSubjectMinutes, longestSessionMinutes, problemsSolved, hardSolved, cardsReviewed, goalsCompleted;
  final int? bestWeekday, bestHour; // weekday 1..7
  final double? avgRating;

  bool get hasData => minutes > 0 || problemsSolved > 0 || cardsReviewed > 0;

  int? get busiestMonth {
    if (monthMinutes.every((m) => m == 0)) return null;
    var best = 0;
    for (var i = 1; i < 12; i++) {
      if (monthMinutes[i] > monthMinutes[best]) best = i;
    }
    return best + 1;
  }
}

/// All the "what does my data say" calculations. Pure functions over a [Snapshot].
class InsightsEngine {
  static List<StudySession> _since(Snapshot s, int days) {
    final from = s.today.subtract(Duration(days: days - 1));
    return s.sessions.where((x) => !fromMs(x.startedAt).isBefore(from)).toList();
  }

  // ----------------------------------------------------------- best hour ---

  static HourInsight hours(Snapshot s, {int days = 90}) {
    final list = _since(s, days);
    final minutes = List<double>.filled(24, 0);
    for (final x in list) {
      _spread(x, minutes);
    }
    final total = minutes.fold(0.0, (a, b) => a + b);
    int? best;
    if (total > 0) {
      best = 0;
      for (var h = 1; h < 24; h++) {
        if (minutes[h] > minutes[best!]) best = h;
      }
    }
    final ratingSum = List<int>.filled(24, 0), ratingN = List<int>.filled(24, 0);
    for (final x in list) {
      if (x.rating == null) continue;
      final h = fromMs(x.startedAt).hour;
      ratingSum[h] += x.rating!;
      ratingN[h]++;
    }
    int? sharp;
    double? sharpRating;
    for (var h = 0; h < 24; h++) {
      if (ratingN[h] < 3) continue;
      final avg = ratingSum[h] / ratingN[h];
      if (sharpRating == null || avg > sharpRating) {
        sharp = h;
        sharpRating = avg;
      }
    }
    return HourInsight(minutes, best, sharp, sharpRating, list.length);
  }

  /// Splits a session's active minutes across the clock hours it spans.
  static void _spread(StudySession x, List<double> into) {
    final totalMin = x.activeSeconds / 60.0;
    if (totalMin <= 0) return;
    final start = x.startedAt;
    final end = x.endedAt ?? start + x.activeSeconds * 1000;
    final wall = end - start;
    if (wall <= 0) {
      into[fromMs(start).hour] += totalMin;
      return;
    }
    var cursor = start;
    while (cursor < end) {
      final d = fromMs(cursor);
      final nextHour = DateTime(d.year, d.month, d.day, d.hour + 1).millisecondsSinceEpoch;
      final sliceEnd = math.min(nextHour, end);
      into[d.hour] += totalMin * (sliceEnd - cursor) / wall;
      cursor = sliceEnd;
    }
  }

  // ----------------------------------------------- focus vs subject -------

  static List<SubjectFocus> focusBySubject(Snapshot s, {int days = 90}) {
    final byId = {for (final x in s.subjects) x.id: x};
    final mins = <String?, int>{}, count = <String?, int>{};
    final ratingSum = <String?, int>{}, ratingN = <String?, int>{};
    for (final x in _since(s, days)) {
      final k = byId.containsKey(x.subjectId) ? x.subjectId : null;
      mins[k] = (mins[k] ?? 0) + x.activeSeconds ~/ 60;
      count[k] = (count[k] ?? 0) + 1;
      if (x.rating != null) {
        ratingSum[k] = (ratingSum[k] ?? 0) + x.rating!;
        ratingN[k] = (ratingN[k] ?? 0) + 1;
      }
    }
    final out = [
      for (final k in mins.keys)
        SubjectFocus(
          k,
          k == null ? 'No subject' : byId[k]!.name,
          k == null ? 0xFF64748B : byId[k]!.color,
          mins[k]!,
          count[k]!,
          (ratingN[k] ?? 0) == 0 ? null : ratingSum[k]! / ratingN[k]!,
        ),
    ]..sort((a, b) => b.minutes.compareTo(a.minutes));
    return out;
  }

  // ------------------------------------------------------------ burnout ---

  static BurnoutReport burnout(Snapshot s) {
    final today = s.today;
    final last7 = s.minutesBetween(today.subtract(const Duration(days: 6)), today.add(const Duration(days: 1)));
    final prior28 = s.minutesBetween(today.subtract(const Duration(days: 34)), today.subtract(const Duration(days: 6)));
    final baseline = (prior28 / 4).round();
    final reasons = <String>[];
    var score = 0;

    if (baseline >= 120 && last7 > baseline * 1.5) {
      final pct = ((last7 / baseline - 1) * 100).round();
      reasons.add('You studied $pct% more this week than your usual week.');
      score += last7 > baseline * 2 ? 2 : 1;
    }

    final longDay = math.max(s.dailyTargetMinutes * 2, 180);
    final longDays = [
      for (var i = 0; i < 7; i++)
        if (s.minutesOn(today.subtract(Duration(days: i))) >= longDay) i
    ].length;
    if (longDays >= 3) {
      reasons.add('$longDays of the last 7 days were very long (over ${longDay ~/ 60} h).');
      score += 1;
    }

    var run = 0;
    for (var i = 0; i < 30; i++) {
      if (s.minutesOn(today.subtract(Duration(days: i))) >= s.minQualifyingMinutes) {
        run++;
      } else {
        break;
      }
    }
    if (run >= 14 && last7 >= s.dailyTargetMinutes * 7) {
      reasons.add('$run days in a row without a rest day.');
      score += 1;
    }

    double? avg(Iterable<StudySession> xs) {
      final r = xs.where((x) => x.rating != null).toList();
      return r.length < 3 ? null : r.fold(0, (a, x) => a + x.rating!) / r.length;
    }

    final recent = avg(_since(s, 7));
    final earlier = avg(_since(s, 28).where((x) => fromMs(x.startedAt).isBefore(today.subtract(const Duration(days: 6)))));
    if (recent != null && earlier != null && earlier - recent >= 1.0) {
      reasons.add('Your self-rated focus dropped from ${earlier.toStringAsFixed(1)} to ${recent.toStringAsFixed(1)}.');
      score += 1;
    }

    final lateNights = _since(s, 7).where((x) => fromMs(x.startedAt).hour < 4).length;
    if (lateNights >= 3) {
      reasons.add('$lateNights sessions started after midnight this week.');
      score += 1;
    }

    final level = score == 0 ? BurnoutLevel.none : (score == 1 ? BurnoutLevel.watch : BurnoutLevel.high);
    final advice = switch (level) {
      BurnoutLevel.none => 'Your pace looks sustainable. Keep it up.',
      BurnoutLevel.watch => 'Worth watching. Plan one lighter day and keep breaks between blocks.',
      BurnoutLevel.high => 'Take a lighter day or two. Short, focused sessions beat long tired ones.',
    };
    return BurnoutReport(level, reasons, advice, last7, baseline);
  }

  // ----------------------------------------------------- year in review ---

  static YearReview yearInReview(Snapshot s, int year) {
    final sessions = s.sessions.where((x) => fromMs(x.startedAt).year == year).toList();
    final monthMinutes = List<int>.filled(12, 0);
    final weekdayMinutes = List<int>.filled(8, 0);
    final dayMinutes = <String, int>{};

    for (final x in sessions) {
      final d = fromMs(x.startedAt);
      final m = x.activeSeconds ~/ 60;
      monthMinutes[d.month - 1] += m;
      weekdayMinutes[d.weekday] += m;
      dayMinutes[dateKey(d)] = (dayMinutes[dateKey(d)] ?? 0) + m;
    }
    for (final p in s.problems) {
      if (p.sessionId != null) continue; // already inside a session
      final d = fromMs(p.attemptedAt);
      if (d.year != year) continue;
      monthMinutes[d.month - 1] += p.minutes;
      weekdayMinutes[d.weekday] += p.minutes;
      dayMinutes[dateKey(d)] = (dayMinutes[dateKey(d)] ?? 0) + p.minutes;
    }
    final solved = s.problems.where((p) => p.result == ProblemResult.solved && fromMs(p.attemptedAt).year == year).toList();

    final active = <String>{
      for (final e in dayMinutes.entries)
        if (e.value >= s.minQualifyingMinutes) e.key,
      for (final p in solved) dateKey(fromMs(p.attemptedAt)),
    };
    final sorted = active.map(parseDate).toList()..sort();
    var longest = 0, run = 0;
    DateTime? prev;
    for (final d in sorted) {
      run = (prev != null && d.difference(prev).inDays == 1) ? run + 1 : 1;
      longest = math.max(longest, run);
      prev = d;
    }

    final bySubject = <String, int>{};
    final names = {for (final x in s.subjects) x.id: x.name};
    for (final x in sessions) {
      final n = names[x.subjectId];
      if (n != null) bySubject[n] = (bySubject[n] ?? 0) + x.activeSeconds ~/ 60;
    }
    final top = bySubject.entries.isEmpty ? null : (bySubject.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;

    int? bestWeekday;
    for (var d = 1; d <= 7; d++) {
      if (weekdayMinutes[d] > 0 && (bestWeekday == null || weekdayMinutes[d] > weekdayMinutes[bestWeekday])) bestWeekday = d;
    }

    final rated = sessions.where((x) => x.rating != null).toList();
    final hourMinutes = List<double>.filled(24, 0);
    for (final x in sessions) {
      _spread(x, hourMinutes);
    }
    int? bestHour;
    for (var h = 0; h < 24; h++) {
      if (hourMinutes[h] > 0 && (bestHour == null || hourMinutes[h] > hourMinutes[bestHour])) bestHour = h;
    }

    return YearReview(
      year: year,
      minutes: monthMinutes.fold(0, (a, b) => a + b),
      sessions: sessions.length,
      activeDays: active.length,
      longestStreak: longest,
      monthMinutes: monthMinutes,
      topSubject: top?.key,
      topSubjectMinutes: top?.value ?? 0,
      bestWeekday: bestWeekday,
      longestSessionMinutes: sessions.fold(0, (a, x) => math.max(a, x.activeSeconds ~/ 60)),
      problemsSolved: solved.length,
      hardSolved: solved.where((p) => p.difficulty == 'Hard').length,
      cardsReviewed: s.cardReviews.where((r) => fromMs(r.reviewedAt).year == year).length,
      goalsCompleted: s.goals.where((g) => g.status == GoalStatus.completed && fromMs(g.updatedAt).year == year).length,
      avgRating: rated.isEmpty ? null : rated.fold(0, (a, x) => a + x.rating!) / rated.length,
      bestHour: bestHour,
    );
  }
}
