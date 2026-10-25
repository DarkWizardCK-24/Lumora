import 'enums.dart';
import '../services/app_database.dart';
import '../utils/date_format.dart';

class Activity {
  Activity({
    String? id,
    required this.title,
    this.subjectId,
    this.goalId,
    this.kind = ActivityKind.study,
    required this.plannedStart,
    required this.plannedEnd,
    this.plannedMinutes = 30,
    this.status = 'planned',
    this.priority = 2,
    this.criteria = '',
    this.notes = '',
    this.generated = false,
    int? createdAt,
    int? updatedAt,
  })  : id = id ?? newId(),
        createdAt = createdAt ?? nowMs(),
        updatedAt = updatedAt ?? nowMs();
  final String id;
  String title, status, criteria, notes;
  String? subjectId, goalId;
  ActivityKind kind;
  int plannedStart, plannedEnd, plannedMinutes, priority, createdAt, updatedAt;
  bool generated;
  DateTime get start => fromMs(plannedStart);
  bool get done => status == 'done';

  factory Activity.fromMap(Map<String, Object?> m) => Activity(
        id: m['id'] as String,
        title: m['title'] as String,
        subjectId: m['subject_id'] as String?,
        goalId: m['goal_id'] as String?,
        kind: enumByName(ActivityKind.values, m['kind'] as String, ActivityKind.study),
        plannedStart: m['planned_start'] as int,
        plannedEnd: m['planned_end'] as int,
        plannedMinutes: m['planned_minutes'] as int,
        status: m['status'] as String,
        priority: m['priority'] as int,
        criteria: m['criteria'] as String,
        notes: m['notes'] as String,
        generated: (m['generated'] as int) == 1,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );
  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'subject_id': subjectId,
        'goal_id': goalId,
        'kind': kind.name,
        'planned_start': plannedStart,
        'planned_end': plannedEnd,
        'planned_minutes': plannedMinutes,
        'status': status,
        'priority': priority,
        'criteria': criteria,
        'notes': notes,
        'generated': generated ? 1 : 0,
        'created_at': createdAt,
        'updated_at': nowMs(),
      };
}
