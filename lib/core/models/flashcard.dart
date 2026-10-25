import '../services/app_database.dart';
import '../utils/date_format.dart';

/// How well the learner recalled a card. The index is stored in the review log.
enum CardGrade {
  again('Again'),
  hard('Hard'),
  good('Good'),
  easy('Easy');

  const CardGrade(this.label);
  final String label;
}

class Flashcard {
  Flashcard({
    String? id,
    required this.deck,
    this.subjectId,
    this.topicId,
    required this.front,
    required this.back,
    this.ease = 2.5,
    this.intervalDays = 0,
    this.reps = 0,
    this.lapses = 0,
    DateTime? due,
    this.lastReviewed,
    int? createdAt,
    int? updatedAt,
  })  : id = id ?? newId(),
        due = due ?? dayOnly(DateTime.now()),
        createdAt = createdAt ?? nowMs(),
        updatedAt = updatedAt ?? nowMs();

  final String id;
  String deck, front, back;
  String? subjectId, topicId;
  double ease;
  int intervalDays, reps, lapses, createdAt, updatedAt;
  DateTime due;
  int? lastReviewed;

  bool get isNew => reps == 0 && lapses == 0 && lastReviewed == null;
  bool isDue(DateTime today) => !due.isAfter(today);

  factory Flashcard.fromMap(Map<String, Object?> m) => Flashcard(
        id: m['id'] as String,
        deck: m['deck'] as String,
        subjectId: m['subject_id'] as String?,
        topicId: m['topic_id'] as String?,
        front: m['front'] as String,
        back: m['back'] as String,
        ease: (m['ease'] as num).toDouble(),
        intervalDays: m['interval_days'] as int,
        reps: m['reps'] as int,
        lapses: m['lapses'] as int,
        due: parseDate(m['due'] as String),
        lastReviewed: m['last_reviewed'] as int?,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'deck': deck,
        'subject_id': subjectId,
        'topic_id': topicId,
        'front': front,
        'back': back,
        'ease': ease,
        'interval_days': intervalDays,
        'reps': reps,
        'lapses': lapses,
        'due': dateKey(due),
        'last_reviewed': lastReviewed,
        'created_at': createdAt,
        'updated_at': nowMs(),
      };
}

class CardReview {
  const CardReview(this.id, this.cardId, this.reviewedAt, this.grade);
  final String id, cardId;
  final int reviewedAt;
  final CardGrade grade;

  factory CardReview.fromMap(Map<String, Object?> m) => CardReview(
        m['id'] as String,
        m['card_id'] as String,
        m['reviewed_at'] as int,
        CardGrade.values[(m['grade'] as int).clamp(0, CardGrade.values.length - 1)],
      );
}
