import 'enums.dart';
import '../services/app_database.dart';
import '../utils/date_format.dart';

class CodingProblem {
  CodingProblem({
    String? id,
    required this.title,
    this.platform = 'LeetCode',
    this.url = '',
    this.subjectId,
    this.topicId,
    this.sessionId,
    this.difficulty = 'Easy',
    this.language = 'Python',
    required this.attemptedAt,
    this.result = ProblemResult.attempted,
    this.minutes = 0,
    this.attempts = 1,
    this.notes = '',
    this.approach = '',
    this.pattern = '',
    this.snippet = '',
    this.revisionRequired = false,
    this.nextReview,
    int? createdAt,
    int? updatedAt,
  })  : id = id ?? newId(),
        createdAt = createdAt ?? nowMs(),
        updatedAt = updatedAt ?? nowMs();
  final String id;
  String title, platform, url, difficulty, language, notes, approach, pattern, snippet;
  String? subjectId, topicId, sessionId;
  int attemptedAt, minutes, attempts, createdAt, updatedAt;
  ProblemResult result;
  bool revisionRequired;
  DateTime? nextReview;

  factory CodingProblem.fromMap(Map<String, Object?> m) => CodingProblem(
        id: m['id'] as String,
        title: m['title'] as String,
        platform: m['platform'] as String,
        url: m['url'] as String,
        subjectId: m['subject_id'] as String?,
        topicId: m['topic_id'] as String?,
        sessionId: m['session_id'] as String?,
        difficulty: m['difficulty'] as String,
        language: m['language'] as String,
        attemptedAt: m['attempted_at'] as int,
        result: enumByName(ProblemResult.values, m['result'] as String, ProblemResult.attempted),
        minutes: m['minutes'] as int,
        attempts: m['attempts'] as int,
        notes: m['notes'] as String,
        approach: m['approach'] as String,
        pattern: (m['pattern'] as String?) ?? '',
        snippet: (m['snippet'] as String?) ?? '',
        revisionRequired: (m['revision_required'] as int) == 1,
        nextReview: m['next_review'] == null ? null : parseDate(m['next_review'] as String),
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );
  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'platform': platform,
        'url': url,
        'subject_id': subjectId,
        'topic_id': topicId,
        'session_id': sessionId,
        'difficulty': difficulty,
        'language': language,
        'attempted_at': attemptedAt,
        'result': result.name,
        'minutes': minutes,
        'attempts': attempts,
        'notes': notes,
        'approach': approach,
        'pattern': pattern,
        'snippet': snippet,
        'revision_required': revisionRequired ? 1 : 0,
        'next_review': nextReview == null ? null : dateKey(nextReview!),
        'created_at': createdAt,
        'updated_at': nowMs(),
      };
}

/// One timed attempt at a problem, used to chart solve-time improvement.
class ProblemAttempt {
  const ProblemAttempt(this.id, this.problemId, this.at, this.seconds, this.solved);
  final String id, problemId;
  final int at, seconds;
  final bool solved;

  factory ProblemAttempt.fromMap(Map<String, Object?> m) => ProblemAttempt(
        m['id'] as String,
        m['problem_id'] as String,
        m['at'] as int,
        m['seconds'] as int,
        (m['solved'] as int) == 1,
      );
}

/// Common algorithm patterns offered when tagging a problem.
const problemPatterns = [
  'Arrays & Hashing',
  'Two Pointers',
  'Sliding Window',
  'Stack',
  'Binary Search',
  'Linked List',
  'Trees',
  'Heap / Priority Queue',
  'Backtracking',
  'Graphs',
  'Dynamic Programming',
  'Greedy',
  'Intervals',
  'Math & Bits',
  'Strings',
  'SQL',
];
