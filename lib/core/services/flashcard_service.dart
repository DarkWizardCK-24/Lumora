import '../models/flashcard.dart';
import '../utils/date_format.dart';
import 'app_database.dart';
import 'repository.dart';
import 'sm2.dart';

extension FlashcardService on Repository {
  Future<List<Flashcard>> flashcards() async => mapRows(
      await db.query('flashcards', orderBy: 'deck COLLATE NOCASE, created_at'), Flashcard.fromMap);

  Future<List<CardReview>> cardReviews() async => mapRows(
      await db.query('flashcard_reviews', orderBy: 'reviewed_at DESC'), CardReview.fromMap);

  Future<void> saveCard(Flashcard c) => db.upsert('flashcards', c.toMap());
  Future<void> deleteCard(String id) => db.delete('flashcards', id);

  Future<void> renameDeck(String from, String to) async {
    await db.transaction((t) async {
      await t.update('flashcards', {'deck': to, 'updated_at': nowMs()},
          where: 'deck = ?', whereArgs: [from]);
    });
  }

  Future<void> deleteDeck(String deck) async {
    await db.transaction((t) async {
      await t.delete('flashcards', where: 'deck = ?', whereArgs: [deck]);
    });
  }

  /// Applies SM-2 to [c], persists it and logs the review in one transaction.
  Future<void> gradeCard(Flashcard c, CardGrade grade, {DateTime? today}) async {
    final n = Sm2.next(c, grade, today ?? DateTime.now());
    c
      ..ease = n.ease
      ..intervalDays = n.intervalDays
      ..reps = n.reps
      ..lapses = n.lapses
      ..due = n.due
      ..lastReviewed = nowMs();
    await db.transaction((t) async {
      await db.upsert('flashcards', c.toMap(), exec: t);
      await t.insert('flashcard_reviews', {
        'id': newId(),
        'card_id': c.id,
        'reviewed_at': nowMs(),
        'grade': grade.index,
      });
    });
  }
}
