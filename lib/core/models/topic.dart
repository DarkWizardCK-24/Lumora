import '../services/app_database.dart';
import '../utils/date_format.dart';

class Topic {
  Topic({
    String? id,
    required this.subjectId,
    this.goalId,
    required this.name,
    this.description = '',
    this.estimatedMinutes = 60,
    this.difficulty = 'Beginner',
    this.status = 'todo',
    this.prerequisiteId,
    this.revisionStatus = 'none',
    int? createdAt,
    int? updatedAt,
  })  : id = id ?? newId(),
        createdAt = createdAt ?? nowMs(),
        updatedAt = updatedAt ?? nowMs();
  final String id;
  String subjectId, name, description, difficulty, status, revisionStatus;
  String? goalId, prerequisiteId;
  int estimatedMinutes, createdAt, updatedAt;

  factory Topic.fromMap(Map<String, Object?> m) => Topic(
        id: m['id'] as String,
        subjectId: m['subject_id'] as String,
        goalId: m['goal_id'] as String?,
        name: m['name'] as String,
        description: m['description'] as String,
        estimatedMinutes: m['estimated_minutes'] as int,
        difficulty: m['difficulty'] as String,
        status: m['status'] as String,
        prerequisiteId: m['prerequisite_id'] as String?,
        revisionStatus: m['revision_status'] as String,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );
  Map<String, Object?> toMap() => {
        'id': id,
        'subject_id': subjectId,
        'goal_id': goalId,
        'name': name,
        'description': description,
        'estimated_minutes': estimatedMinutes,
        'difficulty': difficulty,
        'status': status,
        'prerequisite_id': prerequisiteId,
        'revision_status': revisionStatus,
        'created_at': createdAt,
        'updated_at': nowMs(),
      };
}
