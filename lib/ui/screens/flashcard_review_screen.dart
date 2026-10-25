import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/colors/app_colors.dart';
import '../../core/models/flashcard.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/repository.dart';
import '../../core/services/sm2.dart';
import '../../core/utils/date_format.dart';
import '../widgets/empty_state.dart';
import '../widgets/flip_card.dart';
import '../widgets/page_layout.dart';
import '../widgets/progress_bar.dart';

/// Spaced-repetition session: shows due cards one at a time and grades them with SM-2.
class FlashcardReviewScreen extends ConsumerStatefulWidget {
  const FlashcardReviewScreen({super.key, this.deck});
  final String? deck; // null = every due card
  @override
  ConsumerState<FlashcardReviewScreen> createState() => _FlashcardReviewScreenState();
}

class _FlashcardReviewScreenState extends ConsumerState<FlashcardReviewScreen> {
  List<Flashcard>? _queue;
  int _total = 0, _done = 0;
  bool _flipped = false, _busy = false;
  final _tally = <CardGrade, int>{for (final g in CardGrade.values) g: 0};
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _leave() => context.canPop() ? context.pop() : context.go('/flashcards');

  Future<void> _load() async {
    final today = dayOnly(DateTime.now());
    final all = await ref.read(repoProvider).flashcards();
    final due = all
        .where((c) => c.isDue(today))
        .where((c) => widget.deck == null || c.deck == widget.deck)
        .toList()
      ..sort((a, b) => a.due.compareTo(b.due));
    if (!mounted) return;
    setState(() {
      _queue = due;
      _total = due.length;
    });
  }

  Future<void> _grade(CardGrade g) async {
    final q = _queue;
    if (q == null || q.isEmpty || !_flipped || _busy) return;
    _busy = true;
    HapticFeedback.selectionClick();
    final card = q.first;
    await ref.read(repoProvider).gradeCard(card, g);
    _tally[g] = (_tally[g] ?? 0) + 1;
    if (!mounted) return;
    setState(() {
      q.removeAt(0);
      if (g == CardGrade.again) {
        q.add(card); // relearn later in this session
      } else {
        _done++;
      }
      _flipped = false;
      _busy = false;
    });
  }

  KeyEventResult _onKey(FocusNode n, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter) {
      setState(() => _flipped = !_flipped);
      return KeyEventResult.handled;
    }
    final i = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
    ].indexOf(k);
    if (i >= 0) {
      _grade(CardGrade.values[i]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final q = _queue;
    if (q == null) return const LoadingView();
    if (_total == 0) {
      return EmptyState(
          icon: Icons.task_alt_rounded,
          title: 'Nothing due',
          message: 'You are all caught up. Come back when cards are due again.',
          action: FilledButton(onPressed: _leave, child: const Text('Back to decks')));
    }
    if (q.isEmpty) return _summary();
    final card = q.first;
    final today = DateTime.now();
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: PageBody(maxWidth: 720, children: [
        Row(children: [
          IconButton(tooltip: 'End session', onPressed: _leave, icon: const Icon(Icons.close_rounded)),
          Expanded(child: ProgressBar(_total == 0 ? 0 : _done / _total, height: 10)),
          const SizedBox(width: 12),
          Text('$_done / $_total', style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(card.deck, style: const TextStyle(color: Palette.muted))),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                  position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(a), child: c)),
          child: KeyedSubtree(
              key: ValueKey('${card.id}-${_tally.values.fold(0, (a, b) => a + b)}'),
              child: FlipCard(
                  front: card.front,
                  back: card.back,
                  flipped: _flipped,
                  onTap: () => setState(() => _flipped = !_flipped))),
        ),
        const SizedBox(height: 20),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _flipped ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                  onPressed: () => setState(() => _flipped = true),
                  icon: const Icon(Icons.flip_rounded),
                  label: const Text('Show answer'))),
          secondChild: Row(children: [
            for (final g in CardGrade.values) ...[
              if (g.index > 0) const SizedBox(width: 8),
              Expanded(child: _GradeButton(g, Sm2.previewLabel(card, g, today), () => _grade(g))),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        const Center(
            child: Text('Space flips · 1 Again · 2 Hard · 3 Good · 4 Easy',
                style: TextStyle(color: Palette.muted, fontSize: 12))),
      ]),
    );
  }

  Widget _summary() {
    final good = (_tally[CardGrade.good] ?? 0) + (_tally[CardGrade.easy] ?? 0);
    final reviews = _tally.values.fold(0, (a, b) => a + b);
    return PageBody(maxWidth: 560, children: [
      const SizedBox(height: 24),
      Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (c, v, child) => Transform.scale(scale: v, child: child),
          child: const Icon(Icons.celebration_rounded, size: 72, color: Palette.warning),
        ),
      ),
      const SizedBox(height: 12),
      const Center(child: Text('Session complete', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700))),
      const SizedBox(height: 6),
      Center(
          child: Text(
              '$_total cards cleared · ${reviews == 0 ? 0 : (good * 100 / reviews).round()}% recalled well',
              style: const TextStyle(color: Palette.muted))),
      const SizedBox(height: 20),
      Row(children: [
        for (final g in CardGrade.values)
          Expanded(
              child: Card(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(children: [
                        Text('${_tally[g]}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                        Text(g.label, style: const TextStyle(color: Palette.muted, fontSize: 12)),
                      ])))),
      ]),
      const SizedBox(height: 20),
      FilledButton(onPressed: _leave, child: const Text('Back to decks')),
    ]);
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton(this.grade, this.hint, this.onTap);
  final CardGrade grade;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (grade) {
      CardGrade.again => Palette.danger,
      CardGrade.hard => Palette.warning,
      CardGrade.good => Palette.success,
      CardGrade.easy => Palette.brandBlue,
    };
    return FilledButton(
      style: FilledButton.styleFrom(
          backgroundColor: color, minimumSize: const Size(48, 56), padding: const EdgeInsets.symmetric(horizontal: 4)),
      onPressed: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(grade.label, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(hint, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ]),
    );
  }
}
