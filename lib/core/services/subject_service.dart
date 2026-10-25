import '../models/subject.dart';
import '../models/topic.dart';
import 'repository.dart';

extension SubjectService on Repository {
  Future<List<Subject>> subjects({bool includeArchived = true}) async => mapRows(
      await db.query('subjects',
          where: includeArchived ? null : 'archived = 0', orderBy: 'name COLLATE NOCASE'),
      Subject.fromMap);
  Future<void> saveSubject(Subject s) => db.upsert('subjects', s.toMap());

  /// Deleting a subject cascades to its topics; sessions, goals, notes and
  /// problems are preserved and simply unlinked (ON DELETE SET NULL).
  Future<void> deleteSubject(String id) async {
    final topics = await db.query('topics', where: 'subject_id = ?', args: [id]);
    for (final t in topics) {
      await db.delete('topics', t['id'] as String);
    }
    await db.delete('subjects', id);
  }

  Future<int> subjectLinkCounts(String id) async {
    var n = 0;
    for (final t in ['study_sessions', 'learning_goals', 'notes', 'coding_problems']) {
      final r = await db.raw('SELECT COUNT(*) c FROM $t WHERE subject_id = ?', [id]);
      n += r.first['c'] as int;
    }
    return n;
  }

  Future<List<Topic>> topics({String? subjectId, String? goalId}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (subjectId != null) {
      where.add('subject_id = ?');
      args.add(subjectId);
    }
    if (goalId != null) {
      where.add('goal_id = ?');
      args.add(goalId);
    }
    return mapRows(
        await db.query('topics',
            where: where.isEmpty ? null : where.join(' AND '), args: args, orderBy: 'created_at'),
        Topic.fromMap);
  }

  Future<void> saveTopic(Topic t) => db.upsert('topics', t.toMap());
  Future<void> deleteTopic(String id) => db.delete('topics', id);

}
