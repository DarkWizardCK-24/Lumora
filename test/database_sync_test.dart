import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lumora/core/models/enums.dart';
import 'package:lumora/core/models/goal.dart';
import 'package:lumora/core/models/milestone.dart';
import 'package:lumora/core/models/note.dart';
import 'package:lumora/core/models/subject.dart';
import 'package:lumora/core/models/topic.dart';
import 'package:lumora/core/services/app_database.dart';
import 'package:lumora/core/services/backup_service.dart';
import 'package:lumora/core/services/remote_store.dart';
import 'package:lumora/core/services/repository.dart';
import 'package:lumora/core/services/schema.dart';
import 'package:lumora/core/services/sync_service.dart';

class FakeRemote implements RemoteStore {
  final docs = <String, Map<String, Object?>>{};
  final removed = <String>[];
  bool failNext = false, failTransient = true;
  int puts = 0;
  List<RemoteDoc> pull = [];

  @override
  bool get signedIn => true;
  @override
  String? get email => 'a@b.c';
  @override
  Future<void> signUp(String e, String p) async {}
  @override
  Future<void> signIn(String e, String p) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> restore() async {}
  @override
  Future<void> put(String type, String id, Map<String, Object?> data) async {
    if (failNext) throw SyncException('offline', transient: failTransient);
    puts++;
    docs['$type/$id'] = data; // PUT by id => idempotent
  }

  @override
  Future<void> remove(String type, String id, int deletedAt) async {
    if (failNext) throw SyncException('offline');
    removed.add('$type/$id');
    docs.remove('$type/$id');
  }

  @override
  Future<List<RemoteDoc>> pullSince(int after) async => pull;
}

void main() {
  late AppDatabase db;
  late Repository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    repo = Repository(db);
  });
  tearDown(() => db.close());

  group('database', () {
    test('migrations create the schema and record the version', () async {
      final v = await db.raw('SELECT MAX(version) v FROM schema_migrations');
      expect(v.first['v'], schemaVersion);
      final tables = (await db.raw("SELECT name FROM sqlite_master WHERE type='table'")).map((r) => r['name']).toSet();
      expect(tables, containsAll(['subjects', 'learning_goals', 'study_sessions', 'sync_outbox', 'deletion_tombstones']));
    });

    test('foreign keys are enforced', () async {
      expect(() => repo.saveTopic(Topic(subjectId: 'missing', name: 'x')), throwsA(isA<DatabaseException>()));
    });

    test('CRUD round-trip with UUID ids', () async {
      final s = Subject(name: 'Python');
      await repo.saveSubject(s);
      expect(s.id.length, 36);
      s.name = 'Python 3';
      await repo.saveSubject(s);
      expect((await repo.subjects()).single.name, 'Python 3');
      await repo.deleteSubject(s.id);
      expect(await repo.subjects(), isEmpty);
    });

    test('deleting a subject keeps linked goals, unlinked; deleting a goal keeps sessions', () async {
      final s = Subject(name: 'S');
      await repo.saveSubject(s);
      final g = Goal(title: 'G', subjectId: s.id);
      await repo.saveGoal(g);
      await repo.saveMilestone(Milestone(goalId: g.id, title: 'M'));
      final sess = await repo.startSession(goalId: g.id, subjectId: s.id, type: SessionType.learning);
      await repo.finishSession(sess);
      await repo.deleteSubject(s.id);
      expect((await repo.goals()).single.subjectId, isNull);
      await repo.deleteGoal(g.id);
      expect(await repo.milestones(), isEmpty);
      expect((await repo.sessions()).single.goalId, isNull);
    });

    test('a failing transaction rolls back completely', () async {
      final s = Subject(name: 'Rollback');
      await expectLater(
          db.transaction((t) async {
            await db.upsert('subjects', s.toMap(), exec: t);
            throw StateError('boom');
          }),
          throwsStateError);
      expect(await repo.subjects(), isEmpty);
      expect(await db.query('sync_outbox'), isEmpty);
    });

    test('notes search matches title, body and tags', () async {
      await repo.saveNote(Note(title: 'Recursion', body: 'base case', tags: 'dsa'));
      await repo.saveNote(Note(title: 'Other', body: 'x'));
      expect((await repo.notes(query: 'base')).length, 1);
      expect((await repo.notes(query: 'dsa')).length, 1);
      expect((await repo.notes(query: 'zzz')), isEmpty);
    });
  });

  group('timer', () {
    test('start is idempotent, finish is idempotent, pause intervals are excluded', () async {
      final a = await repo.startSession(type: SessionType.learning);
      final b = await repo.startSession(type: SessionType.revision);
      expect(b.id, a.id); // no duplicate sessions
      await repo.pauseSession(a);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await repo.resumeSession(a);
      await repo.finishSession(a, notes: 'n');
      await repo.finishSession(a, notes: 'again');
      final done = await repo.sessions();
      expect(done.length, 1);
      expect(done.single.notes, 'n');
      expect((await repo.pauses(a.id)).single.endedAt, isNotNull);
    });

    test('unfinished session is recoverable', () async {
      final s = await repo.startSession(type: SessionType.learning);
      final recovered = await repo.activeSession();
      expect(recovered?.id, s.id);
      expect(await repo.sessions(), isEmpty); // not counted until saved
    });
  });

  group('outbox', () {
    test('record change and outbox entry are written together; edits collapse', () async {
      final s = Subject(name: 'A');
      await repo.saveSubject(s);
      s.name = 'B';
      await repo.saveSubject(s);
      final rows = await db.query('sync_outbox');
      expect(rows.length, 1);
      expect(jsonDecode(rows.single['payload'] as String)['name'], 'B');
    });

    test('delete writes a tombstone and a delete op', () async {
      final s = Subject(name: 'A');
      await repo.saveSubject(s);
      await repo.deleteSubject(s.id);
      expect((await db.query('deletion_tombstones')).length, 1);
      expect((await db.query('sync_outbox')).single['op'], 'delete');
    });
  });

  group('sync', () {
    late FakeRemote remote;
    late SyncService sync;
    setUp(() {
      remote = FakeRemote();
      sync = SyncService(db, remote);
    });

    test('failed push keeps the operation, with backoff and error', () async {
      await repo.saveSubject(Subject(name: 'A'));
      remote.failNext = true;
      await sync.syncNow();
      final r = (await db.query('sync_outbox')).single;
      expect(r['status'], 'pending');
      expect(r['attempts'], 1);
      expect(r['last_error'], 'offline');
      expect(r['next_retry_at'] as int, greaterThan(DateTime.now().millisecondsSinceEpoch));
      expect(sync.last.state, SyncState.failed);
    });

    test('successful push removes the op only after confirmation', () async {
      await repo.saveSubject(Subject(name: 'A'));
      await sync.syncNow();
      expect(remote.docs.length, 1);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(sync.last.state, SyncState.synced);
    });

    test('retry after reconnection delivers pending work exactly once', () async {
      await repo.saveSubject(Subject(name: 'A'));
      remote.failNext = true;
      await sync.syncNow();
      remote.failNext = false;
      await db.db.update('sync_outbox', {'next_retry_at': 0});
      await sync.syncNow();
      await sync.syncNow();
      expect(remote.puts, 1);
    });

    test('non-transient errors become failed and can be retried', () async {
      await repo.saveSubject(Subject(name: 'A'));
      remote
        ..failNext = true
        ..failTransient = false;
      await sync.syncNow();
      expect((await db.query('sync_outbox')).single['status'], 'failed');
      remote.failNext = false;
      await sync.retryFailed();
      expect(await db.query('sync_outbox'), isEmpty);
    });

    test('backoff is exponential and bounded', () {
      expect(SyncService.backoff(1) > SyncService.backoff(0), isTrue);
      expect(SyncService.backoff(40), SyncService.maxBackoff);
    });

    test('deletes propagate', () async {
      final s = Subject(name: 'A');
      await repo.saveSubject(s);
      await sync.syncNow();
      await repo.deleteSubject(s.id);
      await sync.syncNow();
      expect(remote.removed, contains('subjects/${s.id}'));
    });

    test('pull inserts remote rows, skips tombstoned ids, and flags conflicts', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      Map<String, Object?> row(String id, String name, int updated) => Subject(id: id, name: name, updatedAt: updated).toMap()
        ..['updated_at'] = updated
        ..['version'] = 1;

      // new remote row is inserted
      remote.pull = [RemoteDoc('subjects', 'r1', row('r1', 'Remote', now))];
      await sync.syncNow();
      expect((await repo.subjects()).map((s) => s.name), contains('Remote'));

      // locally deleted id must not reappear
      final gone = Subject(name: 'Gone');
      await repo.saveSubject(gone);
      await sync.syncNow();
      await repo.deleteSubject(gone.id);
      remote.pull = [RemoteDoc('subjects', gone.id, row(gone.id, 'Gone', now + 1000))];
      await sync.syncNow();
      expect((await repo.subjects()).any((s) => s.id == gone.id), isFalse);

      // local unsent edit + newer remote edit => conflict; local copy is kept
      final mine = Subject(name: 'Mine');
      await repo.saveSubject(mine);
      await sync.syncNow();
      mine.name = 'Mine edited locally';
      await repo.saveSubject(mine);
      // keep the op pending (not yet due) so it is still unsent during the pull
      await db.db.update('sync_outbox', {'next_retry_at': DateTime.now().millisecondsSinceEpoch + 600000});
      remote.pull = [RemoteDoc('subjects', mine.id, row(mine.id, 'Mine remote', DateTime.now().millisecondsSinceEpoch + 5000))];
      await sync.syncNow();
      final conflicts = await sync.conflictList();
      expect(conflicts.any((c) => c.id == mine.id), isTrue);
      expect((await repo.subjects()).firstWhere((x) => x.id == mine.id).name, 'Mine edited locally');
      await sync.resolveConflict(conflicts.firstWhere((c) => c.id == mine.id), keepLocal: false);
      expect((await repo.subjects()).firstWhere((x) => x.id == mine.id).name, 'Mine remote');
    });

    test('initial merge queues every local record without overwriting', () async {
      await repo.saveSubject(Subject(name: 'A'));
      await db.db.delete('sync_outbox');
      await sync.queueFullUpload();
      expect((await db.query('sync_outbox')).length, 1);
    });
  });

  group('backup & restore', () {
    test('round trip merges without overwriting and skips duplicates', () async {
      final s = Subject(name: 'Python');
      await repo.saveSubject(s);
      await repo.saveTopic(Topic(subjectId: s.id, name: 'Loops'));
      final backup = jsonEncode(await BackupService(db).snapshotJson());

      final preview = await BackupService(db).preview(backup);
      expect(preview.totalNew, 0);
      expect(preview.totalDuplicates, greaterThan(0));

      s.name = 'Changed after backup';
      await repo.saveSubject(s);
      await db.db.delete('topics');
      final restoreSvc = BackupService(db);
      final p2 = await restoreSvc.preview(backup);
      expect(p2.newRows['topics'], 1);
    });

    test('rejects files that are not Lumora backups', () async {
      expect(() => BackupService(db).preview('{"hello":1}'), throwsFormatException);
      expect(() => BackupService(db).preview('nope'), throwsFormatException);
    });

    test('delete-all wipes learning data but keeps preferences', () async {
      await repo.saveSubject(Subject(name: 'A'));
      await db.setPref('theme', 'dark');
      await BackupService(db).deleteAllLocalData();
      expect(await repo.subjects(), isEmpty);
      expect(await db.pref('theme'), 'dark');
    });
  });
}
