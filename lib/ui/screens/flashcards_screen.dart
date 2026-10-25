import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/colors/app_colors.dart';
import '../../core/models/flashcard.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/repository.dart';
import '../../core/services/snapshot.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/responsive.dart';
import '../flows/flashcard_flow.dart';
import '../widgets/app_stat_card.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/new_action_scope.dart';
import '../widgets/page_layout.dart';
import '../widgets/progress_ring.dart';
import '../widgets/section_card.dart';

/// A card counts as "mastered" once its review interval reaches three weeks.
const _masteredDays = 21;

class FlashcardsScreen extends ConsumerWidget {
  const FlashcardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(snapshotProvider).when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
          data: (s) => _Body(s),
        );
  }
}

class _Body extends ConsumerWidget {
  const _Body(this.s);
  final Snapshot s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = Responsive.isCompact(context);
    final decks = <String, List<Flashcard>>{};
    for (final c in s.cards) {
      decks.putIfAbsent(c.deck, () => []).add(c);
    }
    final names = decks.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final due = s.cardsDue;
    final todayKey = dateKey(s.today);
    final reviewedToday = s.cardReviews.where((r) => dateKey(fromMs(r.reviewedAt)) == todayKey).length;
    final since = s.today.subtract(const Duration(days: 30));
    final recent = s.cardReviews.where((r) => fromMs(r.reviewedAt).isAfter(since)).toList();
    final recalled = recent.where((r) => r.grade.index >= CardGrade.good.index).length;
    final mastered = s.cards.where((c) => c.intervalDays >= _masteredDays).length;

    return NewActionScope(
      onNew: () => editCard(context, ref, s),
      child: PageBody(children: [
        PageHeader(title: 'Flashcards', subtitle: 'Spaced repetition that works fully offline', actions: [
          OutlinedButton.icon(
              onPressed: () => editCard(context, ref, s), icon: const Icon(Icons.add), label: const Text('Add card')),
          FilledButton.icon(
              onPressed: due == 0 ? null : () => context.push('/flashcards/review'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(due == 0 ? 'All caught up' : 'Review $due due')),
        ]),
        AdaptiveGrid(minTile: compact ? 150 : 220, maxColumns: 4, minColumns: 2, children: [
          StatCard(
              label: 'Due today',
              value: '$due',
              footer: due == 0 ? 'Nothing waiting' : 'Tap to review',
              icon: Icons.style_rounded,
              colors: Grads.indigo,
              onTap: due == 0 ? null : () => context.push('/flashcards/review')),
          StatCard(
              label: 'Reviewed today',
              value: '$reviewedToday',
              footer: '${s.cardReviews.length} all time',
              icon: Icons.check_circle_outline,
              colors: Grads.emerald),
          StatCard(
              label: 'Mastered',
              value: '$mastered',
              footer: 'of ${s.cards.length} cards',
              icon: Icons.workspace_premium_rounded,
              colors: Grads.amber),
          StatCard(
              label: 'Recall rate',
              value: recent.isEmpty ? '—' : '${(recalled * 100 / recent.length).round()}%',
              footer: 'last 30 days',
              icon: Icons.psychology_rounded,
              colors: Grads.violet),
        ]),
        const SizedBox(height: 16),
        if (names.isEmpty)
          SizedBox(
              height: 320,
              child: EmptyState(
                  icon: Icons.style_outlined,
                  title: 'No flashcards yet',
                  message: 'Create a deck, add question and answer cards, and Lumora schedules each review for you.',
                  action: FilledButton.icon(
                      onPressed: () => editCard(context, ref, s), icon: const Icon(Icons.add), label: const Text('Create first card'))))
        else
          AdaptiveGrid(minTile: 340, maxColumns: 3, children: [
            for (final n in names) _DeckCard(s, n, decks[n]!),
          ]),
      ]),
    );
  }
}

class _DeckCard extends ConsumerWidget {
  const _DeckCard(this.s, this.name, this.cards);
  final Snapshot s;
  final String name;
  final List<Flashcard> cards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = cards.where((c) => c.isDue(s.today)).length;
    final fresh = cards.where((c) => c.isNew).length;
    final mastered = cards.where((c) => c.intervalDays >= _masteredDays).length;
    final progress = cards.isEmpty ? 0.0 : mastered / cards.length;
    final repo = ref.read(repoProvider);
    return SectionCard(
      title: name,
      trailing: PopupMenuButton<String>(
        tooltip: 'Deck options',
        onSelected: (v) async {
          switch (v) {
            case 'add':
              await editCard(context, ref, s, deck: name);
            case 'browse':
              await _browse(context, ref);
            case 'rename':
              final to = await askDeckName(context, initial: name);
              if (to != null && to != name) await repo.renameDeck(name, to);
            case 'delete':
              if (await confirm(context, 'Delete deck?', 'Remove "$name" and its ${cards.length} cards?')) {
                await repo.deleteDeck(name);
              }
          }
        },
        itemBuilder: (c) => const [
          PopupMenuItem(value: 'add', child: Text('Add card')),
          PopupMenuItem(value: 'browse', child: Text('Browse cards')),
          PopupMenuItem(value: 'rename', child: Text('Rename deck')),
          PopupMenuItem(value: 'delete', child: Text('Delete deck')),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ProgressRing(
              value: progress,
              size: 64,
              color: Palette.success,
              child: Text('${(progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          const SizedBox(width: 16),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${cards.length} cards', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('$due due · $fresh new · $mastered mastered', style: const TextStyle(color: Palette.muted, fontSize: 12.5)),
          ])),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: FilledButton(
                  onPressed: due == 0 ? null : () => context.push('/flashcards/review?deck=${Uri.encodeQueryComponent(name)}'),
                  child: Text(due == 0 ? 'Up to date' : 'Review $due'))),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: () => _browse(context, ref), child: const Text('Browse')),
        ]),
      ]),
    );
  }

  Future<void> _browse(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (c) => _DeckBrowser(name),
    );
  }
}

/// Live list of one deck's cards with edit and delete.
class _DeckBrowser extends ConsumerWidget {
  const _DeckBrowser(this.deck);
  final String deck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(snapshotProvider).value;
    final cards = s?.cards.where((c) => c.deck == deck).toList() ?? const <Flashcard>[];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
          child: Row(children: [
            Expanded(child: Text(deck, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            if (s != null)
              TextButton.icon(
                  onPressed: () => editCard(context, ref, s, deck: deck), icon: const Icon(Icons.add), label: const Text('Add')),
          ]),
        ),
        Expanded(
          child: cards.isEmpty
              ? const EmptyState(icon: Icons.style_outlined, title: 'Empty deck', message: 'Add a card to get started.')
              : ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: cards.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, i) {
                    final c = cards[i];
                    return ListTile(
                      title: Text(c.front, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${c.back}\n${c.isNew ? 'New' : 'Next in ${c.due.difference(s!.today).inDays.clamp(0, 9999)} d · ease ${c.ease.toStringAsFixed(1)}'}',
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                      isThreeLine: true,
                      onTap: s == null ? null : () => editCard(context, ref, s, card: c),
                      trailing: IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            if (await confirm(context, 'Delete card?', 'This card and its history will be removed.')) {
                              await ref.read(repoProvider).deleteCard(c.id);
                            }
                          }),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
