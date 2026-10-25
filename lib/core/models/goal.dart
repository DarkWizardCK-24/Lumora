import 'enums.dart';
import '../services/app_database.dart';
import '../utils/date_format.dart';

class Goal {
  Goal({
    String? id,
    required this.title,
    this.description = '',
    this.subjectId,
    this.currentLevel = 0,
    this.targetLevel = 5,
    DateTime? startDate,
    this.deadline,
    this.estimatedMinutes,
    this.remainingMinutes,
    this.priority = 2,
    this.status = GoalStatus.notStarted,
    this.tags = '',
    this.manualProgress,
    this.criteria = '',
    this.notes = '',
    int? createdAt,
    int? updatedAt,
    this.archived = false,
  })  : id = id ?? newId(),
        startDate = startDate ?? dayOnly(DateTime.now()),
        createdAt = createdAt ?? nowMs(),
        updatedAt = updatedAt ?? nowMs();
  final String id;
  String title, description, tags, criteria, notes;
  String? subjectId;
  int currentLevel, targetLevel, priority, createdAt, updatedAt;
  DateTime startDate;
  DateTime? deadline;
  int? estimatedMinutes, remainingMinutes, manualProgress;
  GoalStatus status;
  bool archived;

  List<String> get tagList =>
      tags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  factory Goal.fromMap(Map<String, Object?> m) => Goal(
        id: m['id'] as String,
        title: m['title'] as String,
        description: m['description'] as String,
        subjectId: m['subject_id'] as String?,
        currentLevel: m['current_level'] as int,
        targetLevel: m['target_level'] as int,
        startDate: parseDate(m['start_date'] as String),
        deadline: m['deadline'] == null ? null : parseDate(m['deadline'] as String),
        estimatedMinutes: m['estimated_minutes'] as int?,
        remainingMinutes: m['remaining_minutes'] as int?,
        priority: m['priority'] as int,
        status: enumByName(GoalStatus.values, m['status'] as String, GoalStatus.notStarted),
        tags: m['tags'] as String,
        manualProgress: m['manual_progress'] as int?,
        criteria: m['criteria'] as String,
        notes: m['notes'] as String,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
        archived: (m['archived'] as int) == 1,
      );
  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'subject_id': subjectId,
        'current_level': currentLevel,
        'target_level': targetLevel,
        'start_date': dateKey(startDate),
        'deadline': deadline == null ? null : dateKey(deadline!),
        'estimated_minutes': estimatedMinutes,
        'remaining_minutes': remainingMinutes,
        'priority': priority,
        'status': status.name,
        'tags': tags,
        'manual_progress': manualProgress,
        'criteria': criteria,
        'notes': notes,
        'created_at': createdAt,
        'updated_at': nowMs(),
        'archived': archived ? 1 : 0,
      };
}
