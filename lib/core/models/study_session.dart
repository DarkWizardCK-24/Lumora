import 'enums.dart';
import '../services/app_database.dart';
import '../utils/date_format.dart';

class Pause {
  Pause({String? id, required this.sessionId, required this.startedAt, this.endedAt})
      : id = id ?? newId();
  final String id;
  final String sessionId;
  final int startedAt;
  int? endedAt;
  factory Pause.fromMap(Map<String, Object?> m) => Pause(
      id: m['id'] as String,
      sessionId: m['session_id'] as String,
      startedAt: m['started_at'] as int,
      endedAt: m['ended_at'] as int?);
  Map<String, Object?> toMap() => {
        'id': id,
        'session_id': sessionId,
        'started_at': startedAt,
        'ended_at': endedAt,
        'created_at': startedAt,
        'updated_at': nowMs(),
      };
}

class StudySession {
  StudySession({
    String? id,
    this.subjectId,
    this.topicId,
    this.goalId,
    this.type = SessionType.learning,
    required this.startedAt,
    this.endedAt,
    this.activeSeconds = 0,
    this.status = SessionStatus.running,
    this.notes = '',
    this.rating,
    int? createdAt,
    int? updatedAt,
  })  : id = id ?? newId(),
        createdAt = createdAt ?? nowMs(),
        updatedAt = updatedAt ?? nowMs();
  final String id;
  String? subjectId, topicId, goalId;
  SessionType type;
  int startedAt, activeSeconds, createdAt, updatedAt;
  int? endedAt, rating;
  SessionStatus status;
  String notes;

  /// Active duration derived from persisted timestamps and pause intervals —
  /// never from an in-memory counter, so it survives restarts.
  static int computeActiveSeconds(int startMs, int endMs, Iterable<Pause> pauses) {
    var paused = 0;
    for (final p in pauses) {
      final s = p.startedAt.clamp(startMs, endMs);
      final e = (p.endedAt ?? endMs).clamp(startMs, endMs);
      if (e > s) paused += e - s;
    }
    final total = (endMs - startMs) - paused;
    return total <= 0 ? 0 : total ~/ 1000;
  }

  factory StudySession.fromMap(Map<String, Object?> m) => StudySession(
        id: m['id'] as String,
        subjectId: m['subject_id'] as String?,
        topicId: m['topic_id'] as String?,
        goalId: m['goal_id'] as String?,
        type: enumByName(SessionType.values, m['session_type'] as String, SessionType.learning),
        startedAt: m['started_at'] as int,
        endedAt: m['ended_at'] as int?,
        activeSeconds: m['active_seconds'] as int,
        status: enumByName(SessionStatus.values, m['status'] as String, SessionStatus.completed),
        notes: m['notes'] as String,
        rating: m['rating'] as int?,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );
  Map<String, Object?> toMap() => {
        'id': id,
        'subject_id': subjectId,
        'topic_id': topicId,
        'goal_id': goalId,
        'session_type': type.name,
        'started_at': startedAt,
        'ended_at': endedAt,
        'active_seconds': activeSeconds,
        'status': status.name,
        'notes': notes,
        'rating': rating,
        'created_at': createdAt,
        'updated_at': nowMs(),
      };
}
