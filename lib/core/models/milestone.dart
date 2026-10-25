import '../services/app_database.dart';
import '../utils/date_format.dart';

class Milestone {
  Milestone({
    String? id,
    required this.goalId,
    required this.title,
    this.description = '',
    this.dueDate,
    this.completedAt,
    this.criteria = '',
    this.estimatedMinutes = 0,
    int? createdAt,
    int? updatedAt,
  })  : id = id ?? newId(),
        createdAt = createdAt ?? nowMs(),
        updatedAt = updatedAt ?? nowMs();
  final String id;
  String goalId, title, description, criteria;
  DateTime? dueDate;
  int? completedAt;
  int estimatedMinutes, createdAt, updatedAt;
  bool get done => completedAt != null;

  factory Milestone.fromMap(Map<String, Object?> m) => Milestone(
        id: m['id'] as String,
        goalId: m['goal_id'] as String,
        title: m['title'] as String,
        description: m['description'] as String,
        dueDate: m['due_date'] == null ? null : parseDate(m['due_date'] as String),
        completedAt: m['completed_at'] as int?,
        criteria: m['criteria'] as String,
        estimatedMinutes: m['estimated_minutes'] as int,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );
  Map<String, Object?> toMap() => {
        'id': id,
        'goal_id': goalId,
        'title': title,
        'description': description,
        'due_date': dueDate == null ? null : dateKey(dueDate!),
        'completed_at': completedAt,
        'status': done ? 'done' : 'open',
        'criteria': criteria,
        'estimated_minutes': estimatedMinutes,
        'created_at': createdAt,
        'updated_at': nowMs(),
      };
}
