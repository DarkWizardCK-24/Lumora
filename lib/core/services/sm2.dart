import '../models/flashcard.dart';
import '../utils/date_format.dart';

/// SM-2 style scheduling with four grades. Pure functions so they are easy to test.
class Sm2 {
  static const minEase = 1.3;

  /// Returns the scheduling state after grading [c] on [today]; [c] is not mutated.
  static ({double ease, int intervalDays, int reps, int lapses, DateTime due}) next(
      Flashcard c, CardGrade grade, DateTime today) {
    var ease = c.ease, interval = c.intervalDays, reps = c.reps, lapses = c.lapses;
    switch (grade) {
      case CardGrade.again:
        lapses += 1;
        reps = 0;
        interval = 0; // relearn: shown again today
        ease = (ease - 0.2).clamp(minEase, 3.0);
      case CardGrade.hard:
        interval = interval <= 0 ? 1 : (interval * 1.2).round().clamp(interval + 1, 100000);
        reps += 1;
        ease = (ease - 0.15).clamp(minEase, 3.0);
      case CardGrade.good:
        interval = reps == 0
            ? 1
            : reps == 1
                ? 3
                : (interval * ease).round().clamp(interval + 1, 100000);
        reps += 1;
      case CardGrade.easy:
        interval = reps == 0 ? 4 : (interval * ease * 1.3).round().clamp(interval + 2, 100000);
        reps += 1;
        ease = (ease + 0.15).clamp(minEase, 3.0);
    }
    final base = dayOnly(today);
    return (
      ease: ease,
      intervalDays: interval,
      reps: reps,
      lapses: lapses,
      due: DateTime(base.year, base.month, base.day + interval),
    );
  }

  /// Short label for the grade button, e.g. "10 min", "3 d", "2 mo".
  static String previewLabel(Flashcard c, CardGrade g, DateTime today) {
    final d = next(c, g, today).intervalDays;
    if (d <= 0) return '<10 min';
    if (d < 30) return '$d d';
    if (d < 365) return '${(d / 30).round()} mo';
    return '${(d / 365).toStringAsFixed(1)} y';
  }
}
