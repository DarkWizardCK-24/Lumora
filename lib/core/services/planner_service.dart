import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import '../models/activity.dart';
import 'app_database.dart';
import 'repository.dart';
import '../utils/date_format.dart';

extension PlannerService on Repository {
  Future<List<Activity>> activities({String? goalId, DateTime? from, DateTime? to}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (goalId != null) {
      where.add('goal_id = ?');
      args.add(goalId);
    }
    if (from != null) {
      where.add('planned_start >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('planned_start < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    return mapRows(
        await db.query('scheduled_activities',
            where: where.isEmpty ? null : where.join(' AND '),
            args: args,
            orderBy: 'planned_start'),
        Activity.fromMap);
  }

  Future<void> saveActivity(Activity a) => db.upsert('scheduled_activities', a.toMap());
  Future<void> deleteActivity(String id) => db.delete('scheduled_activities', id);

  /// Applies an approved schedule: keeps done activities, replaces future
  /// generated, not-done ones. Runs atomically and logs a revision.
  Future<void> applySchedule(String goalId, List<Activity> proposed, String reason) async {
    final existing = await activities(goalId: goalId);
    final now = nowMs();
    final removable = existing
        .where((a) => a.generated && !a.done && a.status != 'skipped' && a.plannedStart >= now)
        .toList();
    await db.transaction((t) async {
      for (final a in removable) {
        await t.delete('scheduled_activities', where: 'id = ?', whereArgs: [a.id]);
        await t.insert('deletion_tombstones',
            {'entity_type': 'scheduled_activities', 'entity_id': a.id, 'deleted_at': now},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final a in proposed) {
        await db.upsert('scheduled_activities', a.toMap(), exec: t);
      }
      await t.insert('schedule_revisions', {
        'id': newId(),
        'goal_id': goalId,
        'reason': reason,
        'summary': 'Removed ${removable.length}, added ${proposed.length} activities',
        'created_at': now,
      });
    });
  }

  /// Minutes available per weekday (DateTime.monday..sunday = 1..7).
  Future<Map<int, int>> availability() async {
    final rows = await db.query('study_availability');
    final m = {for (var d = 1; d <= 7; d++) d: d <= 5 ? 60 : 90};
    for (final r in rows) {
      m[r['weekday'] as int] = r['minutes'] as int;
    }
    return m;
  }

  Future<void> setAvailability(int weekday, int minutes) async {
    await db.db.insert('study_availability', {'weekday': weekday, 'minutes': minutes},
        conflictAlgorithm: ConflictAlgorithm.replace);
    db.notifyChanged();
  }

}
