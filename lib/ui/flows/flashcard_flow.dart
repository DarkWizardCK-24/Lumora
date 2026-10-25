import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/flashcard.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/repository.dart';
import '../../core/services/snapshot.dart';
import '../../core/utils/pickers.dart';
import '../widgets/form_dialog.dart';

/// Adds or edits a card. [deck] pre-fills the deck name for new cards.
Future<void> editCard(BuildContext context, WidgetRef ref, Snapshot s,
    {Flashcard? card, String? deck}) async {
  final v = await showForm(context,
      title: card == null ? 'Add flashcard' : 'Edit flashcard',
      fields: [
        const FText('deck', 'Deck', required: true, hint: 'e.g. Dart basics'),
        const FText('front', 'Front (question)', required: true, multiline: true),
        const FText('back', 'Back (answer)', required: true, multiline: true),
        FChoice('subjectId', 'Subject', subjectOptions(s), allowNone: true),
      ],
      initial: {
        'deck': card?.deck ?? deck,
        'front': card?.front,
        'back': card?.back,
        'subjectId': card?.subjectId,
      });
  if (v == null) return;
  final c = card ?? Flashcard(deck: '', front: '', back: '');
  c
    ..deck = (v['deck'] as String).trim()
    ..front = (v['front'] as String).trim()
    ..back = (v['back'] as String).trim()
    ..subjectId = v['subjectId'] as String?;
  await ref.read(repoProvider).saveCard(c);
}

Future<String?> askDeckName(BuildContext context, {String? initial}) async {
  final v = await showForm(context,
      title: initial == null ? 'New deck' : 'Rename deck',
      fields: const [FText('name', 'Deck name', required: true)],
      initial: {'name': initial});
  final name = (v?['name'] as String?)?.trim();
  return (name == null || name.isEmpty) ? null : name;
}
