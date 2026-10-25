import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lumora/core/models/enums.dart';
import 'package:lumora/core/services/app_database.dart';
import 'package:lumora/core/services/auth_service.dart';
import 'package:lumora/core/services/repository.dart';
import 'package:lumora/core/services/roadmap_python_mastery.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('imports the roadmap once, linked correctly, and never seeds on its own', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final repo = Repository(db);
    expect(await repo.goals(), isEmpty);

    final r = await importPythonMasteryRoadmap(repo, today: DateTime(2026, 10, 25));
    expect(r.alreadyImported, isFalse);
    expect(r.goals, 10); // 8 phases + master + DSA count
    expect(r.topics, 42);
    expect(r.notes, 3);

    final goals = await repo.goals();
    final phase1 = goals.firstWhere((g) => g.title.startsWith('Phase 1'));
    expect(phase1.status, GoalStatus.inProgress);
    expect(phase1.startDate, DateTime(2026, 10, 25));
    expect(goals.firstWhere((g) => g.title.startsWith('Phase 2')).status, GoalStatus.notStarted);
    expect(goals.firstWhere((g) => g.title.startsWith('Python Mastery')).deadline, DateTime(2027, 9, 30));

    final topics = await repo.topics();
    expect(topics.every((t) => t.goalId != null), isTrue);
    expect((await repo.milestones()).length, r.milestones);

    final again = await importPythonMasteryRoadmap(repo, today: DateTime(2026, 10, 26));
    expect(again.alreadyImported, isTrue);
    expect((await repo.goals()).length, goals.length);
    await db.close();
  });

  test('reuses existing subjects and topics instead of duplicating them', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final repo = Repository(db);
    await importPythonMasteryRoadmap(repo, today: DateTime(2026, 10, 25));
    final names = (await repo.subjects()).map((s) => s.name).toList();
    expect(names.toSet().length, names.length);
    await db.close();
  });

  test('first open of an account feeds the roadmap once, even after it is deleted', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final repo = Repository(db);
    final first = await addPythonRoadmapOnce(db);
    expect(first?.goals, 10);
    expect((await repo.goals()).length, 10);
    for (final g in await repo.goals()) {
      await repo.deleteGoal(g.id);
    }
    expect(await addPythonRoadmapOnce(db), isNull);
    expect(await repo.goals(), isEmpty);
    await db.close();
  });

  test('end to end: sign up, roadmap fed into the encrypted db, survives sign out and sign in', () async {
    final dir = await Directory.systemTemp.createTemp('lumora_e2e');
    final auth = await AuthService.open(dataDir: dir.path, iterations: 50);
    final r = await auth.signUp(name: 'Ada', email: 'a@b.co', password: 'secret1');

    var db = await AppDatabase.open(path: await auth.openData(r.user, r.key));
    await addPythonRoadmapOnce(db);
    await db.close();
    await auth.sealData(r.user, r.key);
    expect(File(auth.dbPath(r.user)).existsSync(), isFalse);

    final again = await auth.signIn(email: 'a@b.co', password: 'secret1');
    db = await AppDatabase.open(path: await auth.openData(again.user, again.key));
    final repo = Repository(db);
    expect((await repo.goals()).length, 10);
    expect((await repo.topics()).length, 42);
    expect((await repo.notes()).length, 3);
    expect(await addPythonRoadmapOnce(db), isNull);
    await db.close();
    await auth.close();
    await dir.delete(recursive: true);
  });
}
