import '../services/app_database.dart';
import '../utils/date_format.dart';

class Subject {
  Subject({
    String? id,
    required this.name,
    this.description = '',
    this.icon = 'book',
    this.color = 0xFF0891B2,
    this.category = 'General',
    this.difficulty = 'Beginner',
    this.targetHours = 0,
    this.goalId,
    int? createdAt,
    int? updatedAt,
    this.archived = false,
  })  : id = id ?? newId(),
        createdAt = createdAt ?? nowMs(),
        updatedAt = updatedAt ?? nowMs();
  final String id;
  String name, description, icon, category, difficulty;
  int color;
  double targetHours;
  String? goalId;
  int createdAt, updatedAt;
  bool archived;

  factory Subject.fromMap(Map<String, Object?> m) => Subject(
        id: m['id'] as String,
        name: m['name'] as String,
        description: m['description'] as String,
        icon: m['icon'] as String,
        color: m['color'] as int,
        category: m['category'] as String,
        difficulty: m['difficulty'] as String,
        targetHours: (m['target_hours'] as num).toDouble(),
        goalId: m['goal_id'] as String?,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
        archived: (m['archived'] as int) == 1,
      );
  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'icon': icon,
        'color': color,
        'category': category,
        'difficulty': difficulty,
        'target_hours': targetHours,
        'goal_id': goalId,
        'created_at': createdAt,
        'updated_at': nowMs(),
        'archived': archived ? 1 : 0,
      };
}
