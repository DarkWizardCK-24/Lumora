import 'dart:math' as math;
import '../models/enums.dart';
import 'snapshot.dart';
import '../utils/date_format.dart';

class StreakInfo {
  StreakInfo(this.current, this.longest, this.activeDays, {this.frozenDays = const {}, this.freezeReady = false});
  final int current, longest;
  final Set<String> activeDays;

  /// Missed days that a streak freeze covered. They keep the streak alive without counting as study.
  final Set<String> frozenDays;

  /// True when this week's freeze has not been used yet.
  final bool freezeReady;
}

class StreakEngine {
  /// Derived from stored activity every time — no increment-only counters,
  /// so deleted or backdated sessions are handled automatically.
  ///
  /// With [Snapshot.streakFreezeEnabled], one missed day per calendar week (Mon–Sun) is
  /// forgiven if the day before it was a real study day.
  static StreakInfo compute(Snapshot s) {
    final totals = <String, int>{};
    for (final x in s.sessions) {
      final k = dateKey(fromMs(x.startedAt));
      totals[k] = (totals[k] ?? 0) + x.activeSeconds ~/ 60;
    }
    final days = <String>{
      for (final e in totals.entries)
        if (e.value >= s.minQualifyingMinutes) e.key,
      for (final p in s.problems)
        if (p.result == ProblemResult.solved) dateKey(fromMs(p.attemptedAt)),
    };
    final today = s.today;
    final freezeReadyDefault = s.streakFreezeEnabled;
    if (days.isEmpty) return StreakInfo(0, 0, days, freezeReady: freezeReadyDefault);

    final first = days.map(parseDate).reduce((a, b) => a.isBefore(b) ? a : b);
    String weekKey(DateTime d) => dateKey(DateTime(d.year, d.month, d.day - (d.weekday - 1)));

    var longest = 0, run = 0;
    var prevWasStudy = false;
    final frozen = <String>{}, usedWeeks = <String>{};
    for (var d = first; !d.isAfter(today); d = DateTime(d.year, d.month, d.day + 1)) {
      final k = dateKey(d);
      if (days.contains(k)) {
        run++;
        prevWasStudy = true;
        longest = math.max(longest, run);
      } else if (d == today) {
        // Today is still pending: it neither extends nor breaks the streak yet.
      } else if (s.streakFreezeEnabled && prevWasStudy && !usedWeeks.contains(weekKey(d))) {
        frozen.add(k);
        usedWeeks.add(weekKey(d));
        prevWasStudy = false;
      } else {
        run = 0;
        prevWasStudy = false;
      }
    }
    return StreakInfo(run, longest, days,
        frozenDays: frozen, freezeReady: s.streakFreezeEnabled && !usedWeeks.contains(weekKey(today)));
  }
}
