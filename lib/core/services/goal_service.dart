import '../models/goal.dart';
import '../models/milestone.dart';
import 'repository.dart';

extension GoalService on Repository {
  Future<List<Goal>> goals() async => mapRows(
      await db.query('learning_goals', orderBy: 'priority DESC, deadline IS NULL, deadline'),
      Goal.fromMap);
  Future<Goal?> goal(String id) async {
    final r = await db.byId('learning_goals', id);
    return r == null ? null : Goal.fromMap(r);
  }

  Future<void> saveGoal(Goal g) => db.upsert('learning_goals', g.toMap());

  /// Deleting a goal removes its milestones & generated activities; sessions,
  /// notes and topics are kept and unlinked.
  Future<void> deleteGoal(String id) async {
    for (final m in await milestones(goalId: id)) {
      await db.delete('goal_milestones', m.id);
    }
    for (final a in await activities(goalId: id)) {
      await db.delete('scheduled_activities', a.id);
    }
    await db.delete('learning_goals', id);
  }

  Future<List<Milestone>> milestones({String? goalId}) async => mapRows(
      await db.query('goal_milestones',
          where: goalId == null ? null : 'goal_id = ?',
          args: goalId == null ? null : [goalId],
          orderBy: 'due_date IS NULL, due_date, created_at'),
      Milestone.fromMap);
  Future<void> saveMilestone(Milestone m) => db.upsert('goal_milestones', m.toMap());
  Future<void> deleteMilestone(String id) => db.delete('goal_milestones', id);

}
