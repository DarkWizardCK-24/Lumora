import 'app_database.dart';
export 'subject_service.dart';
export 'goal_service.dart';
export 'session_service.dart';
export 'planner_service.dart';
export 'practice_service.dart';
export 'notes_service.dart';
export 'engagement_service.dart';
export 'flashcard_service.dart';

/// Typed data access. All writes go through [AppDatabase.upsert]/[delete] so
/// that outbox entries and tombstones are committed with the record.
class Repository {
  Repository(this.db);
  final AppDatabase db;

  List<T> mapRows<T>(List<Map<String, Object?>> rows, T Function(Map<String, Object?>) f) =>
      rows.map(f).toList();

}
