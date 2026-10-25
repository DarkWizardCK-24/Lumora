import 'dart:math' as math;
import '../models/enums.dart';
import 'snapshot.dart';
import 'streak_engine.dart';

class XpSource {
  const XpSource(this.label, this.xp, this.detail);
  final String label, detail;
  final int xp;
}

class XpInfo {
  const XpInfo(this.xp, this.level, this.levelStartXp, this.nextLevelXp, this.sources);
  final int xp, level, levelStartXp, nextLevelXp;
  final List<XpSource> sources;

  int get intoLevel => xp - levelStartXp;
  int get levelSpan => nextLevelXp - levelStartXp;
  int get toNext => nextLevelXp - xp;
  double get progress => levelSpan <= 0 ? 0 : (intoLevel / levelSpan).clamp(0.0, 1.0);
  String get title => XpEngine.titleFor(level);
  AvatarTier get tier => XpEngine.tierFor(level);
}

enum AvatarTier { starter, bronze, silver, gold, diamond }

/// XP is derived from stored records on every load, exactly like streaks, so deleting or
/// backdating data can never leave a stale counter behind.
class XpEngine {
  static const perStudyMinute = 1;
  static const focusedSessionBonus = 10; // self-rated 4 or 5
  static const perCardReview = 2;
  static const perActiveDay = 10;
  static const perMilestone = 50;
  static const perGoal = 200;
  static const perAchievement = 100;
  static const _solveXp = {'Easy': 20, 'Medium': 40, 'Hard': 80};
  static const attemptedProblemXp = 5;

  /// Total XP needed to reach [level] (level 1 starts at 0): 100, 300, 600, 1000, ...
  static int xpForLevel(int level) => level <= 1 ? 0 : 50 * level * (level - 1);

  static int levelForXp(int xp) {
    if (xp <= 0) return 1;
    var level = ((1 + math.sqrt(1 + xp / 12.5)) / 2).floor();
    while (xpForLevel(level + 1) <= xp) {
      level++;
    }
    while (level > 1 && xpForLevel(level) > xp) {
      level--;
    }
    return level;
  }

  static const _titles = [
    'Curious Beginner', // 1-2
    'Steady Learner', // 3-4
    'Focused Student', // 5-6
    'Practice Pro', // 7-8
    'Knowledge Seeker', // 9-10
    'Deep Diver', // 11-12
    'Master Learner', // 13-14
    'Lumora Legend', // 15+
  ];

  static String titleFor(int level) => _titles[math.min((level - 1) ~/ 2, _titles.length - 1)];

  static AvatarTier tierFor(int level) => level >= 15
      ? AvatarTier.diamond
      : level >= 10
          ? AvatarTier.gold
          : level >= 5
              ? AvatarTier.silver
              : level >= 3
                  ? AvatarTier.bronze
                  : AvatarTier.starter;

  static XpInfo compute(Snapshot s, {int achievements = 0}) {
    final sources = <XpSource>[];
    void add(String label, int xp, String detail) {
      if (xp > 0) sources.add(XpSource(label, xp, detail));
    }

    final studyMin = s.sessions.fold<int>(0, (a, x) => a + x.activeSeconds ~/ 60);
    add('Study time', studyMin * perStudyMinute, '$studyMin min of sessions');

    final focused = s.sessions.where((x) => (x.rating ?? 0) >= 4).length;
    add('Focused sessions', focused * focusedSessionBonus, '$focused rated 4 or 5');

    var problemXp = 0, solved = 0;
    for (final p in s.problems) {
      if (p.result == ProblemResult.solved) {
        problemXp += _solveXp[p.difficulty] ?? 20;
        solved++;
      } else {
        problemXp += attemptedProblemXp;
      }
    }
    add('Coding practice', problemXp, '$solved solved of ${s.problems.length}');

    add('Flashcard reviews', s.cardReviews.length * perCardReview, '${s.cardReviews.length} reviews');

    final active = StreakEngine.compute(s).activeDays.length;
    add('Active days', active * perActiveDay, '$active days of learning');

    final ms = s.milestones.where((m) => m.done).length;
    add('Milestones', ms * perMilestone, '$ms completed');

    final goals = s.goals.where((g) => g.status == GoalStatus.completed).length;
    add('Goals completed', goals * perGoal, '$goals goals');

    add('Achievements', achievements * perAchievement, '$achievements earned');

    final xp = sources.fold<int>(0, (a, x) => a + x.xp);
    final level = levelForXp(xp);
    return XpInfo(xp, level, xpForLevel(level), xpForLevel(level + 1), sources);
  }
}
