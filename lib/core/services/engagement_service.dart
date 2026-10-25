import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'repository.dart';
import '../utils/date_format.dart';

extension EngagementService on Repository {
  Future<Map<String, String>> dismissedTips() async {
    final rows = await db.query('coaching_tip_history');
    return {for (final r in rows) r['tip_key'] as String: r['fingerprint'] as String};
  }

  Future<void> dismissTip(String key, String fingerprint) async {
    await db.db.insert('coaching_tip_history',
        {'tip_key': key, 'dismissed_at': nowMs(), 'fingerprint': fingerprint},
        conflictAlgorithm: ConflictAlgorithm.replace);
    db.notifyChanged();
  }

  Future<Map<String, int>> achievements() async {
    final rows = await db.query('achievements');
    return {for (final r in rows) r['code'] as String: r['earned_at'] as int};
  }

  Future<void> award(String code) async {
    await db.db.insert('achievements', {'code': code, 'earned_at': nowMs()},
        conflictAlgorithm: ConflictAlgorithm.ignore); // never duplicates
  }
}
