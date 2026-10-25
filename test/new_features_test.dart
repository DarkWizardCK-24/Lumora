import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lumora/core/colors/theme_palettes.dart';
import 'package:lumora/core/models/coding_problem.dart';
import 'package:lumora/core/models/enums.dart';
import 'package:lumora/core/models/flashcard.dart';
import 'package:lumora/core/models/goal.dart';
import 'package:lumora/core/models/study_session.dart';
import 'package:lumora/core/models/subject.dart';
import 'package:lumora/core/services/app_database.dart';
import 'package:lumora/core/services/backup_service.dart';
import 'package:lumora/core/services/insights_engine.dart';
import 'package:lumora/core/services/pomodoro.dart';
import 'package:lumora/core/services/repository.dart';
import 'package:lumora/core/services/schema.dart';
import 'package:lumora/core/services/sm2.dart';
import 'package:lumora/core/services/snapshot.dart';
import 'package:lumora/core/services/streak_engine.dart';
import 'package:lumora/core/services/xp_engine.dart';
import 'package:lumora/core/theme/app_theme.dart';
import 'package:lumora/core/utils/code_tokens.dart';
import 'package:lumora/core/utils/date_format.dart';

final _now = DateTime(2026, 10, 24, 12);

StudySession _session(DateTime start, int minutes, {String? subjectId, int? rating}) => StudySession(
      subjectId: subjectId,
      startedAt: start.millisecondsSinceEpoch,
      endedAt: start.add(Duration(minutes: minutes)).millisecondsSinceEpoch,
      activeSeconds: minutes * 60,
      status: SessionStatus.completed,
      rating: rating,
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SM-2 scheduling', () {
    final today = DateTime(2026, 10, 24);

    test('good answers grow the interval 1 -> 3 -> ease-scaled', () {
      var c = Flashcard(deck: 'd', front: 'f', back: 'b', due: today);
      var n = Sm2.next(c, CardGrade.good, today);
      expect(n.intervalDays, 1);
      expect(n.due, DateTime(2026, 10, 25));
      c
        ..intervalDays = n.intervalDays
        ..reps = n.reps
        ..ease = n.ease;
      n = Sm2.next(c, CardGrade.good, today);
      expect(n.intervalDays, 3);
      c
        ..intervalDays = n.intervalDays
        ..reps = n.reps;
      n = Sm2.next(c, CardGrade.good, today);
      expect(n.intervalDays, 8); // 3 * 2.5 rounded
    });

    test('again resets reps, counts a lapse and lowers ease but never below the floor', () {
      final c = Flashcard(deck: 'd', front: 'f', back: 'b', reps: 5, intervalDays: 20, ease: 1.35);
      final n = Sm2.next(c, CardGrade.again, today);
      expect(n.reps, 0);
      expect(n.lapses, 1);
      expect(n.intervalDays, 0);
      expect(n.due, today); // shown again today
      expect(n.ease, Sm2.minEase);
    });

    test('easy beats good beats hard, and hard always moves forward', () {
      final c = Flashcard(deck: 'd', front: 'f', back: 'b', reps: 3, intervalDays: 10);
      final hard = Sm2.next(c, CardGrade.hard, today).intervalDays;
      final good = Sm2.next(c, CardGrade.good, today).intervalDays;
      final easy = Sm2.next(c, CardGrade.easy, today).intervalDays;
      expect(hard, greaterThan(10));
      expect(good, greaterThan(hard));
      expect(easy, greaterThan(good));
      expect(Sm2.previewLabel(c, CardGrade.again, today), '<10 min');
    });

    test('the input card is never mutated', () {
      final c = Flashcard(deck: 'd', front: 'f', back: 'b');
      Sm2.next(c, CardGrade.easy, today);
      expect(c.reps, 0);
      expect(c.intervalDays, 0);
    });
  });

  group('flashcards in SQLite', () {
    late AppDatabase db;
    late Repository repo;
    setUp(() async {
      db = await AppDatabase.open(path: inMemoryDatabasePath);
      repo = Repository(db);
    });
    tearDown(() => db.close());

    test('grading persists scheduling and writes a review log row', () async {
      final c = Flashcard(deck: 'Dart', front: 'What is a Future?', back: 'A value that arrives later');
      await repo.saveCard(c);
      expect((await repo.flashcards()).single.isNew, isTrue);

      await repo.gradeCard(c, CardGrade.good);
      final saved = (await repo.flashcards()).single;
      expect(saved.reps, 1);
      expect(saved.intervalDays, 1);
      expect(saved.isDue(dayOnly(DateTime.now())), isFalse);
      final log = await repo.cardReviews();
      expect(log.single.grade, CardGrade.good);
      expect(log.single.cardId, c.id);
    });

    test('deleting a card removes its review history; decks can be renamed and deleted', () async {
      final a = Flashcard(deck: 'A', front: '1', back: '1');
      final b = Flashcard(deck: 'A', front: '2', back: '2');
      await repo.saveCard(a);
      await repo.saveCard(b);
      await repo.gradeCard(a, CardGrade.easy);
      await repo.deleteCard(a.id);
      expect(await repo.cardReviews(), isEmpty);

      await repo.renameDeck('A', 'B');
      expect((await repo.flashcards()).single.deck, 'B');
      await repo.deleteDeck('B');
      expect(await repo.flashcards(), isEmpty);
    });

    test('flashcards and attempts are part of the backup', () async {
      await repo.saveCard(Flashcard(deck: 'A', front: 'q', back: 'a'));
      final json = await BackupService(db).snapshotJson();
      final tables = json['tables'] as Map;
      expect(tables['flashcards'], isNotEmpty);
      expect(tables.containsKey('flashcard_reviews'), isTrue);
      expect(tables.containsKey('problem_attempts'), isTrue);
    });
  });

  group('migration', () {
    test('upgrading a version-1 database keeps old problems and adds the new columns', () async {
      final dir = await Directory.systemTemp.createTemp('lumora_mig');
      final path = p.join(dir.path, 'old.db');
      final old = await openDatabase(path, version: 1, onCreate: (d, v) async {
        for (final sql in schemaMigrations[0]) {
          await d.execute(sql);
        }
      });
      await old.insert('coding_problems', {
        'id': 'p1',
        'title': 'Two Sum',
        'attempted_at': 1,
        'created_at': 1,
        'updated_at': 1,
      });
      await old.close();

      final db = await AppDatabase.open(path: path);
      final repo = Repository(db);
      final problem = (await repo.problems()).single;
      expect(problem.title, 'Two Sum');
      expect(problem.pattern, '');
      expect(problem.snippet, '');
      expect(await db.raw('SELECT COUNT(*) c FROM flashcards'), [
        {'c': 0}
      ]);
      await db.close();
      await dir.delete(recursive: true);
    });
  });

  group('coding upgrades', () {
    late AppDatabase db;
    late Repository repo;
    setUp(() async {
      db = await AppDatabase.open(path: inMemoryDatabasePath);
      repo = Repository(db);
    });
    tearDown(() => db.close());

    test('a timed attempt updates the problem and keeps a history', () async {
      final prob = CodingProblem(title: 'Two Sum', attemptedAt: nowMs(), minutes: 10, result: ProblemResult.unsolved);
      await repo.saveProblem(prob);
      await repo.recordAttempt(prob, 25 * 60, solved: false);
      await repo.recordAttempt(prob, 12 * 60, solved: true);

      final saved = (await repo.problems()).single;
      expect(saved.minutes, 10 + 25 + 12);
      expect(saved.attempts, 3);
      expect(saved.result, ProblemResult.solved);
      final history = await repo.attempts(problemId: prob.id);
      expect(history.map((a) => a.seconds), [25 * 60, 12 * 60]);
      expect(history.map((a) => a.solved), [false, true]);
    });

    test('pattern and snippet round-trip, and revisits resurface by date', () async {
      final prob = CodingProblem(title: 'Climb', attemptedAt: nowMs(), pattern: 'Dynamic Programming', snippet: 'def f(): pass');
      await repo.saveProblem(prob);
      await repo.scheduleRevisit(prob, 7);
      var saved = (await repo.problems()).single;
      expect(saved.pattern, 'Dynamic Programming');
      expect(saved.snippet, 'def f(): pass');
      final today = dayOnly(DateTime.now());
      expect(saved.nextReview, DateTime(today.year, today.month, today.day + 7));
      expect(saved.revisionRequired, isFalse); // due by date, not flagged forever

      await repo.completeRevisit(saved, againInDays: 14);
      saved = (await repo.problems()).single;
      expect(saved.nextReview, DateTime(today.year, today.month, today.day + 14));
      await repo.completeRevisit(saved);
      expect((await repo.problems()).single.nextReview, isNull);
    });
  });

  group('code tokenizer', () {
    String join(List<CodeToken> t) => t.map((x) => x.text).join();

    test('never loses or reorders text', () {
      const samples = [
        'def f(x):\n    # note\n    return "a" + \'b\' if x else 3.5\n',
        'SELECT name FROM users WHERE id = 7 -- comment',
        'for (int i = n; i--; ) { /* block\n comment */ s += "x\\"y"; }',
        'unterminated "string',
        '',
      ];
      for (final s in samples) {
        expect(join(tokenizeCode(s)), s);
      }
    });

    test('classifies the common cases', () {
      final t = tokenizeCode('return "hi" # done\nx = 42');
      CodeTokenKind? kindOf(String text) => t.where((x) => x.text == text).firstOrNull?.kind;
      expect(kindOf('return'), CodeTokenKind.keyword);
      expect(kindOf('"hi"'), CodeTokenKind.string);
      expect(kindOf('# done'), CodeTokenKind.comment);
      expect(kindOf('42'), CodeTokenKind.number);
    });

    test('i-- is not mistaken for a SQL comment', () {
      final t = tokenizeCode('while (i--) work();');
      expect(t.where((x) => x.kind == CodeTokenKind.comment), isEmpty);
    });
  });

  group('pomodoro', () {
    test('counts down, freezes while paused and shifts on resume', () {
      var pomo = const Pomodoro(workMin: 25, breakMin: 5, phaseStartMs: 0);
      expect(pomo.remainingSeconds(60 * 1000), 24 * 60);
      pomo = pomo.pause(10 * 60 * 1000);
      expect(pomo.remainingSeconds(20 * 60 * 1000), 15 * 60); // frozen
      expect(pomo.phaseOver(99 * 60 * 1000), isFalse);
      pomo = pomo.resume(20 * 60 * 1000);
      expect(pomo.remainingSeconds(20 * 60 * 1000), 15 * 60);
      expect(pomo.phaseOver(35 * 60 * 1000), isTrue);
    });

    test('alternates work and break, with a long break every fourth cycle', () {
      var pomo = const Pomodoro(workMin: 25, breakMin: 5, phaseStartMs: 0);
      for (var cycle = 1; cycle <= 4; cycle++) {
        expect(pomo.cycle, cycle);
        expect(pomo.onBreak, isFalse);
        pomo = pomo.advance(1000); // -> break
        expect(pomo.onBreak, isTrue);
        expect(pomo.breakLenMin, cycle == 4 ? 15 : 5);
        expect(pomo.isLongBreak, cycle == 4);
        pomo = pomo.advance(2000); // -> next work
      }
      expect(pomo.cycle, 5);
    });

    test('long breaks are capped at 30 minutes', () {
      const pomo = Pomodoro(workMin: 25, breakMin: 20, cycle: 4, phaseStartMs: 0);
      expect(pomo.breakLenMin, 30);
    });
  });

  group('insights', () {
    test('a session spanning two hours is split between them', () {
      final s = Snapshot(now: _now, sessions: [_session(DateTime(2026, 10, 23, 9, 30), 60)]);
      final h = InsightsEngine.hours(s);
      expect(h.minutes[9], closeTo(30, 0.01));
      expect(h.minutes[10], closeTo(30, 0.01));
      expect(h.minutes.reduce((a, b) => a + b), closeTo(60, 0.01));
    });

    test('best hour is where most time is spent; sharpest needs 3+ rated sessions', () {
      final sessions = [
        for (var d = 1; d <= 3; d++) _session(DateTime(2026, 10, 20 + d, 7), 20, rating: 5),
        for (var d = 1; d <= 3; d++) _session(DateTime(2026, 10, 20 + d, 21), 90, rating: 2),
        _session(DateTime(2026, 10, 20, 14), 200, rating: 5), // one rating only: not enough
      ];
      final h = InsightsEngine.hours(Snapshot(now: _now, sessions: sessions));
      expect(h.bestHour, 21); // 3 x 60 min in the 21:00 hour beats 60 min at 14:00
      expect(h.sharpestHour, 7);
      expect(h.sharpestRating, 5);
    });

    test('focus by subject averages ratings and ignores unrated sessions', () {
      final a = Subject(name: 'Math'), b = Subject(name: 'Art');
      final s = Snapshot(now: _now, subjects: [
        a,
        b
      ], sessions: [
        _session(DateTime(2026, 10, 23, 9), 60, subjectId: a.id, rating: 4),
        _session(DateTime(2026, 10, 22, 9), 30, subjectId: a.id, rating: 2),
        _session(DateTime(2026, 10, 21, 9), 30, subjectId: a.id),
        _session(DateTime(2026, 10, 20, 9), 10, subjectId: b.id),
      ]);
      final rows = InsightsEngine.focusBySubject(s);
      expect(rows.first.name, 'Math');
      expect(rows.first.minutes, 120);
      expect(rows.first.avgRating, 3);
      expect(rows.last.avgRating, isNull);
    });

    test('burnout: steady pace with rest days is fine, a week of double hours is flagged', () {
      final steady = [for (var i = 0; i < 35; i++) if (DateTime(2026, 10, 24).subtract(Duration(days: i)).weekday != DateTime.sunday) _session(DateTime(2026, 10, 24).subtract(Duration(days: i)).add(const Duration(hours: 9)), 60)];
      expect(InsightsEngine.burnout(Snapshot(now: _now, sessions: steady)).level, BurnoutLevel.none);

      final spike = [
        for (var i = 7; i < 35; i++) _session(DateTime(2026, 10, 24).subtract(Duration(days: i)).add(const Duration(hours: 9)), 30),
        for (var i = 0; i < 7; i++) _session(DateTime(2026, 10, 24).subtract(Duration(days: i)).add(const Duration(hours: 9)), 240),
      ];
      final r = InsightsEngine.burnout(Snapshot(now: _now, sessions: spike));
      expect(r.level, BurnoutLevel.high);
      expect(r.reasons, isNotEmpty);
    });

    test('burnout: 14+ days with no rest day is at least a watch', () {
      final noRest = [for (var i = 0; i < 35; i++) _session(DateTime(2026, 10, 24).subtract(Duration(days: i)).add(const Duration(hours: 9)), 60)];
      final r = InsightsEngine.burnout(Snapshot(now: _now, sessions: noRest));
      expect(r.level, isNot(BurnoutLevel.none));
      expect(r.reasons.join(' '), contains('without a rest day'));
    });

    test('year in review totals only that year', () {
      final subject = Subject(name: 'Dart');
      final g = Goal(title: 'Ship', startDate: DateTime(2025), status: GoalStatus.completed, updatedAt: DateTime(2026, 6).millisecondsSinceEpoch);
      final s = Snapshot(now: _now, subjects: [
        subject
      ], goals: [
        g
      ], sessions: [
        _session(DateTime(2026, 3, 1, 9), 60, subjectId: subject.id, rating: 4),
        _session(DateTime(2026, 3, 2, 9), 120, subjectId: subject.id, rating: 5),
        _session(DateTime(2025, 12, 31, 9), 500),
      ], problems: [
        CodingProblem(title: 'A', attemptedAt: DateTime(2026, 3, 3).millisecondsSinceEpoch, result: ProblemResult.solved, difficulty: 'Hard', minutes: 15),
      ], cardReviews: [
        CardReview('r', 'c', DateTime(2026, 4, 1).millisecondsSinceEpoch, CardGrade.good),
        CardReview('r2', 'c', DateTime(2025, 4, 1).millisecondsSinceEpoch, CardGrade.good),
      ]);
      final y = InsightsEngine.yearInReview(s, 2026);
      expect(y.sessions, 2);
      expect(y.minutes, 60 + 120 + 15);
      expect(y.activeDays, 3);
      expect(y.longestStreak, 3);
      expect(y.busiestMonth, 3);
      expect(y.topSubject, 'Dart');
      expect(y.problemsSolved, 1);
      expect(y.hardSolved, 1);
      expect(y.cardsReviewed, 1);
      expect(y.goalsCompleted, 1);
      expect(y.avgRating, 4.5);
      expect(InsightsEngine.yearInReview(s, 2030).hasData, isFalse);
    });
  });

  group('streak freeze', () {
    final today = dayOnly(_now); // Saturday 24 Oct 2026

    Snapshot snap(List<int> daysAgo, {bool freeze = true}) => Snapshot(
          now: _now,
          streakFreezeEnabled: freeze,
          sessions: [for (final d in daysAgo) _session(today.subtract(Duration(days: d)).add(const Duration(hours: 9)), 30)],
        );

    test('off by default: one missed day breaks the streak', () {
      final st = StreakEngine.compute(snap([1, 2, 4, 5], freeze: false));
      expect(st.current, 2);
      expect(st.frozenDays, isEmpty);
    });

    test('a single missed day is bridged and does not count as study', () {
      final st = StreakEngine.compute(snap([1, 2, 4, 5]));
      expect(st.current, 4); // days 5,4 + frozen 3 + 2,1
      expect(st.longest, 4);
      expect(st.frozenDays, {dateKey(today.subtract(const Duration(days: 3)))});
      expect(st.activeDays.length, 4);
    });

    test('two missed days in a row still break it', () {
      final st = StreakEngine.compute(snap([1, 2, 5, 6]));
      expect(st.current, 2);
    });

    test('only one freeze per calendar week', () {
      // Missed Mon 19 and Wed 21 (same week as the 24th: Mon 19 - Sun 25).
      final st = StreakEngine.compute(snap([1, 3, 5, 6]));
      expect(st.current, 1);
    });

    test('yesterday missed with today pending keeps the streak alive', () {
      final st = StreakEngine.compute(snap([2, 3, 4]));
      expect(st.current, 3);
      expect(st.freezeReady, isFalse); // this week's freeze is spent
    });

    test('a freeze that is not needed stays ready', () {
      expect(StreakEngine.compute(snap([0, 1, 2])).freezeReady, isTrue);
    });
  });

  group('XP and levels', () {
    test('level curve is monotonic and consistent with its thresholds', () {
      expect(XpEngine.xpForLevel(1), 0);
      expect(XpEngine.xpForLevel(2), 100);
      expect(XpEngine.xpForLevel(3), 300);
      expect(XpEngine.xpForLevel(4), 600);
      for (var xp = 0; xp < 20000; xp += 37) {
        final l = XpEngine.levelForXp(xp);
        expect(xp, greaterThanOrEqualTo(XpEngine.xpForLevel(l)));
        expect(xp, lessThan(XpEngine.xpForLevel(l + 1)));
      }
      expect(XpEngine.levelForXp(99), 1);
      expect(XpEngine.levelForXp(100), 2);
      expect(XpEngine.levelForXp(299), 2);
      expect(XpEngine.levelForXp(300), 3);
    });

    test('XP comes from real records and is itemised', () {
      final s = Snapshot(now: _now, sessions: [
        _session(DateTime(2026, 10, 23, 9), 60, rating: 5),
      ], problems: [
        CodingProblem(title: 'a', attemptedAt: DateTime(2026, 10, 23).millisecondsSinceEpoch, result: ProblemResult.solved, difficulty: 'Hard'),
        CodingProblem(title: 'b', attemptedAt: DateTime(2026, 10, 22).millisecondsSinceEpoch, result: ProblemResult.attempted),
      ], cardReviews: [
        CardReview('1', 'c', 1, CardGrade.good),
        CardReview('2', 'c', 2, CardGrade.easy),
      ]);
      final xp = XpEngine.compute(s, achievements: 1);
      // 60 study + 10 focus + (80 hard solve + 5 attempt) + 4 cards + 1 active day * 10 + 100 achievement
      expect(xp.xp, 60 + 10 + 85 + 4 + 10 + 100);
      expect(xp.sources.fold<int>(0, (a, x) => a + x.xp), xp.xp);
      expect(xp.level, 2);
      expect(xp.progress, inInclusiveRange(0, 1));
    });

    test('no activity means level 1 with no sources', () {
      final xp = XpEngine.compute(Snapshot(now: _now));
      expect(xp.xp, 0);
      expect(xp.level, 1);
      expect(xp.sources, isEmpty);
      expect(xp.tier, AvatarTier.starter);
    });

    test('titles and avatar tiers advance with level', () {
      expect(XpEngine.tierFor(2), AvatarTier.starter);
      expect(XpEngine.tierFor(3), AvatarTier.bronze);
      expect(XpEngine.tierFor(5), AvatarTier.silver);
      expect(XpEngine.tierFor(10), AvatarTier.gold);
      expect(XpEngine.tierFor(15), AvatarTier.diamond);
      expect(XpEngine.titleFor(1), isNot(XpEngine.titleFor(20)));
    });
  });

  group('theming', () {
    test('a custom accent beats the palette, and unknown palettes fall back to the default', () {
      expect(seedFor('forest', 0), paletteById('forest').seed);
      expect(seedFor('forest', 0xFFAA0000), const Color(0xFFAA0000));
      expect(paletteById('nope').id, 'ocean');
    });

    test('AMOLED turns the dark background true black and leaves light untouched', () {
      expect(buildTheme(Brightness.dark, amoled: true).scaffoldBackgroundColor, Colors.black);
      expect(buildTheme(Brightness.dark).scaffoldBackgroundColor, isNot(Colors.black));
      expect(buildTheme(Brightness.light, amoled: true).scaffoldBackgroundColor, isNot(Colors.black));
    });

    test('the seed colour reaches the primary colour', () {
      final t = buildTheme(Brightness.light, seed: const Color(0xFF15803D));
      expect(t.colorScheme.primary, const Color(0xFF15803D));
    });
  });
}
