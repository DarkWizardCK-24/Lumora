import '../services/app_database.dart';
import '../utils/date_format.dart';

class Note {
  Note({
    String? id,
    required this.title,
    this.body = '',
    this.subjectId,
    this.topicId,
    this.goalId,
    this.sessionId,
    this.problemId,
    this.tags = '',
    this.favorite = false,
    this.archived = false,
    int? createdAt,
    int? updatedAt,
  })  : id = id ?? newId(),
        createdAt = createdAt ?? nowMs(),
        updatedAt = updatedAt ?? nowMs();
  final String id;
  String title, body, tags;
  String? subjectId, topicId, goalId, sessionId, problemId;
  bool favorite, archived;
  int createdAt, updatedAt;
  List<String> get tagList =>
      tags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  factory Note.fromMap(Map<String, Object?> m) => Note(
        id: m['id'] as String,
        title: m['title'] as String,
        body: m['body'] as String,
        subjectId: m['subject_id'] as String?,
        topicId: m['topic_id'] as String?,
        goalId: m['goal_id'] as String?,
        sessionId: m['session_id'] as String?,
        problemId: m['problem_id'] as String?,
        tags: m['tags'] as String,
        favorite: (m['favorite'] as int) == 1,
        archived: (m['archived'] as int) == 1,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );
  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'subject_id': subjectId,
        'topic_id': topicId,
        'goal_id': goalId,
        'session_id': sessionId,
        'problem_id': problemId,
        'tags': tags,
        'favorite': favorite ? 1 : 0,
        'archived': archived ? 1 : 0,
        'created_at': createdAt,
        'updated_at': nowMs(),
      };
}
