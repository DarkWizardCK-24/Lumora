import '../models/coding_problem.dart';
import '../models/enums.dart';
import '../utils/date_format.dart';
import 'app_database.dart';
import 'repository.dart';

extension PracticeService on Repository {
  Future<List<CodingProblem>> problems() async => mapRows(
      await db.query('coding_problems', orderBy: 'attempted_at DESC'), CodingProblem.fromMap);
  Future<void> saveProblem(CodingProblem p) => db.upsert('coding_problems', p.toMap());
  Future<void> deleteProblem(String id) => db.delete('coding_problems', id);

  Future<List<ProblemAttempt>> attempts({String? problemId}) async => mapRows(
      await db.query('problem_attempts',
          where: problemId == null ? null : 'problem_id = ?',
          args: problemId == null ? null : [problemId],
          orderBy: 'at'),
      ProblemAttempt.fromMap);

  /// Logs a timed attempt and folds it into the problem's totals atomically.
  Future<void> recordAttempt(CodingProblem p, int seconds, {required bool solved}) async {
    p
      ..minutes += (seconds / 60).ceil()
      ..attempts += 1
      ..attemptedAt = nowMs();
    if (solved) {
      p.result = ProblemResult.solved;
    } else if (p.result == ProblemResult.unsolved) {
      p.result = ProblemResult.attempted;
    }
    await db.transaction((t) async {
      await db.upsert('coding_problems', p.toMap(), exec: t);
      await t.insert('problem_attempts', {
        'id': newId(),
        'problem_id': p.id,
        'at': nowMs(),
        'seconds': seconds,
        'solved': solved ? 1 : 0,
      });
    });
  }

  /// Resurfaces a problem in the revision queue once [days] have passed.
  Future<void> scheduleRevisit(CodingProblem p, int days) {
    final base = dayOnly(DateTime.now());
    p
      ..nextReview = DateTime(base.year, base.month, base.day + days)
      ..revisionRequired = false;
    return saveProblem(p);
  }

  /// Marks a problem as revisited: clears the flag and, if [againInDays] is set, reschedules it.
  Future<void> completeRevisit(CodingProblem p, {int? againInDays}) {
    p
      ..nextReview = null
      ..revisionRequired = false;
    if (p.result == ProblemResult.needsRevision) p.result = ProblemResult.solved;
    if (againInDays != null) {
      final base = dayOnly(DateTime.now());
      p.nextReview = DateTime(base.year, base.month, base.day + againInDays);
    }
    return saveProblem(p);
  }
}
