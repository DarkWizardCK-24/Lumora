import '../models/enums.dart';
import '../models/study_session.dart';
import 'repository.dart';
import '../utils/date_format.dart';

extension SessionService on Repository {
  Future<List<StudySession>> sessions({bool completedOnly = true}) async => mapRows(
      await db.query('study_sessions',
          where: completedOnly ? "status = 'completed'" : null, orderBy: 'started_at DESC'),
      StudySession.fromMap);

  Future<void> saveSession(StudySession s) => db.upsert('study_sessions', s.toMap());
  Future<void> deleteSession(String id) => db.delete('study_sessions', id);

  Future<List<Pause>> pauses(String sessionId) async => mapRows(
      await db.query('session_pauses',
          where: 'session_id = ?', args: [sessionId], orderBy: 'started_at'),
      Pause.fromMap);

  /// The unfinished (running/paused) session, if any — used for crash recovery.
  Future<StudySession?> activeSession() async {
    final r = await db.query('study_sessions',
        where: "status IN ('running','paused')", orderBy: 'started_at DESC', limit: 1);
    return r.isEmpty ? null : StudySession.fromMap(r.first);
  }

  Future<StudySession> startSession(
      {String? subjectId, String? topicId, String? goalId, required SessionType type}) async {
    final existing = await activeSession();
    if (existing != null) return existing; // prevents duplicate sessions
    final s = StudySession(
        subjectId: subjectId, topicId: topicId, goalId: goalId, type: type, startedAt: nowMs());
    await saveSession(s);
    return s;
  }

  Future<void> pauseSession(StudySession s) async {
    if (s.status != SessionStatus.running) return;
    await db.transaction((t) async {
      s.status = SessionStatus.paused;
      await db.upsert('study_sessions', s.toMap(), exec: t);
      await db.upsert('session_pauses', Pause(sessionId: s.id, startedAt: nowMs()).toMap(),
          exec: t);
    });
  }

  Future<void> resumeSession(StudySession s) async {
    if (s.status != SessionStatus.paused) return;
    await db.transaction((t) async {
      final open = await t.query('session_pauses',
          where: 'session_id = ? AND ended_at IS NULL', whereArgs: [s.id]);
      for (final r in open) {
        final p = Pause.fromMap(r)..endedAt = nowMs();
        await db.upsert('session_pauses', p.toMap(), exec: t);
      }
      s.status = SessionStatus.running;
      await db.upsert('study_sessions', s.toMap(), exec: t);
    });
  }

  Future<int> elapsedSeconds(StudySession s) async {
    final end = s.endedAt ?? nowMs();
    return StudySession.computeActiveSeconds(s.startedAt, end, await pauses(s.id));
  }

  /// Idempotent: a second call on a finished session is a no-op.
  Future<void> finishSession(StudySession s, {String notes = '', int? rating}) async {
    final fresh = await db.byId('study_sessions', s.id);
    if (fresh == null) return;
    final cur = StudySession.fromMap(fresh);
    if (cur.status == SessionStatus.completed || cur.status == SessionStatus.discarded) return;
    await db.transaction((t) async {
      final end = nowMs();
      final open = await t.query('session_pauses',
          where: 'session_id = ? AND ended_at IS NULL', whereArgs: [cur.id]);
      for (final r in open) {
        await db.upsert('session_pauses', (Pause.fromMap(r)..endedAt = end).toMap(), exec: t);
      }
      final ps = mapRows(
          await t.query('session_pauses', where: 'session_id = ?', whereArgs: [cur.id]),
          Pause.fromMap);
      cur
        ..endedAt = end
        ..activeSeconds = StudySession.computeActiveSeconds(cur.startedAt, end, ps)
        ..status = SessionStatus.completed
        ..notes = notes.isEmpty ? cur.notes : notes
        ..rating = rating;
      await db.upsert('study_sessions', cur.toMap(), exec: t);
    });
  }

  Future<void> discardSession(StudySession s) => deleteSession(s.id);

}
