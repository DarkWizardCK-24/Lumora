import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors/app_colors.dart';
import '../../core/colors/status_colors.dart';
import '../../core/models/coding_problem.dart';
import '../../core/models/enums.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/repository.dart';
import '../../core/services/snapshot.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/format.dart';
import '../../core/utils/responsive.dart';
import '../flows/coding_flow.dart';
import '../widgets/app_stat_card.dart';
import '../widgets/charts/difficulty_bar_chart.dart';
import '../widgets/code_view.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/new_action_scope.dart';
import '../widgets/page_layout.dart';
import '../widgets/pill.dart';
import '../widgets/problem_history_sheet.dart';
import '../widgets/problem_timer_dialog.dart';
import '../widgets/section_card.dart';
import '../widgets/subject_stats_card.dart';

enum _View { problems, vault }

bool _needsRevisit(CodingProblem p, DateTime today) =>
    p.revisionRequired ||
    p.result == ProblemResult.needsRevision ||
    (p.nextReview != null && !p.nextReview!.isAfter(today));

class CodingScreen extends ConsumerStatefulWidget {
  const CodingScreen({super.key});
  @override
  ConsumerState<CodingScreen> createState() => _CodingScreenState();
}

class _CodingScreenState extends ConsumerState<CodingScreen> {
  String query = '';
  ProblemResult? result;
  String? difficulty, pattern;
  bool revisionOnly = false;
  _View view = _View.problems;

  @override
  Widget build(BuildContext context) {
    return ref.watch(snapshotProvider).when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
          data: (s) {
            var list = s.problems.toList();
            if (query.isNotEmpty) {
              final q = query.toLowerCase();
              list = list
                  .where((p) =>
                      p.title.toLowerCase().contains(q) ||
                      p.platform.toLowerCase().contains(q) ||
                      p.pattern.toLowerCase().contains(q) ||
                      p.language.toLowerCase().contains(q))
                  .toList();
            }
            if (result != null) list = list.where((p) => p.result == result).toList();
            if (difficulty != null) list = list.where((p) => p.difficulty == difficulty).toList();
            if (pattern != null) list = list.where((p) => p.pattern == pattern).toList();
            final queue = s.problems.where((p) => _needsRevisit(p, s.today)).toList()
              ..sort((a, b) => (a.nextReview ?? DateTime(2100)).compareTo(b.nextReview ?? DateTime(2100)));
            if (revisionOnly) list = list.where((p) => _needsRevisit(p, s.today)).toList();
            final solved = s.problems.where((p) => p.result == ProblemResult.solved).length;
            final compact = Responsive.isCompact(context);
            final patternCounts = <String, (int, int)>{};
            for (final p in s.problems.where((p) => p.pattern.isNotEmpty)) {
              final c = patternCounts[p.pattern] ?? (0, 0);
              patternCounts[p.pattern] = (c.$1 + 1, c.$2 + (p.result == ProblemResult.solved ? 1 : 0));
            }
            final vaultCount = s.problems.where((p) => p.snippet.isNotEmpty).length;
            return NewActionScope(
              onNew: () => editProblem(context, ref, s),
              child: PageBody(children: [
                PageHeader(title: 'Coding Practice', subtitle: 'Works offline — no external API needed', actions: [
                  FilledButton.icon(onPressed: () => editProblem(context, ref, s), icon: const Icon(Icons.add), label: const Text('Log problem')),
                ]),
                AdaptiveGrid(minTile: compact ? 150 : 230, maxColumns: 4, minColumns: 2, children: [
                  StatCard(label: 'Solved', value: '$solved', footer: '${s.problems.length} logged', icon: Icons.check_circle_outline, colors: Grads.emerald),
                  StatCard(
                      label: 'Revision queue',
                      value: '${queue.length}',
                      footer: 'Review soon',
                      icon: Icons.replay_rounded,
                      colors: Grads.orange,
                      onTap: () => setState(() {
                            view = _View.problems;
                            revisionOnly = !revisionOnly;
                          })),
                  StatCard(label: 'Practice time', value: fmtHours(s.problems.fold<int>(0, (a, p) => a + p.minutes)), footer: 'hours on problems', icon: Icons.timer_outlined, colors: Grads.sky),
                  StatCard(
                      label: 'Success rate',
                      value: s.problems.isEmpty ? '—' : '${(solved * 100 / s.problems.length).round()}%',
                      footer: 'solved of attempted',
                      icon: Icons.trending_up_rounded,
                      colors: Grads.violet),
                ]),
                const SizedBox(height: 16),
                if (queue.isNotEmpty) ...[_ResurfaceCard(queue, s.today), const SizedBox(height: 16)],
                if (s.problems.isNotEmpty)
                  AdaptiveGrid(minTile: 420, maxColumns: 2, children: [
                    SectionCard(title: 'Difficulty distribution', child: DifficultyBarChart(s.problems)),
                    SectionCard(title: 'By subject / topic', child: SubjectStatsCard(s)),
                  ]),
                if (patternCounts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Patterns',
                    trailing: pattern == null ? null : TextButton(onPressed: () => setState(() => pattern = null), child: const Text('Clear filter')),
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final e in (patternCounts.entries.toList()..sort((a, b) => b.value.$1.compareTo(a.value.$1))))
                        FilterChip(
                          label: Text('${e.key} · ${e.value.$2}/${e.value.$1}'),
                          selected: pattern == e.key,
                          onSelected: (v) => setState(() => pattern = v ? e.key : null),
                        ),
                    ]),
                  ),
                ],
                const SizedBox(height: 16),
                SegmentedButton<_View>(
                  showSelectedIcon: false,
                  segments: [
                    const ButtonSegment(value: _View.problems, icon: Icon(Icons.list_alt_rounded), label: Text('Problems')),
                    ButtonSegment(value: _View.vault, icon: const Icon(Icons.data_object_rounded), label: Text('Snippet vault ($vaultCount)')),
                  ],
                  selected: {view},
                  onSelectionChanged: (v) => setState(() => view = v.first),
                ),
                const SizedBox(height: 12),
                _filters(compact),
                const SizedBox(height: 12),
                if (view == _View.vault)
                  _vault(s, list)
                else if (list.isEmpty)
                  SizedBox(
                      height: 260,
                      child: EmptyState(
                          icon: Icons.code_rounded,
                          title: s.problems.isEmpty ? 'No practice logged' : 'No problems match',
                          message: s.problems.isEmpty ? 'Log a problem from LeetCode, HackerRank, Codeforces, GeeksforGeeks or anywhere else.' : 'Adjust the filters above.'))
                else
                  for (final p in list) _row(context, s, p),
              ]),
            );
          },
        );
  }

  Widget _filters(bool compact) {
    return Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
      SizedBox(
          width: compact ? double.infinity : 260,
          child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search problems, patterns, languages'),
              onChanged: (v) => setState(() => query = v))),
      if (view == _View.problems) ...[
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<ProblemResult?>(
            initialValue: result,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Result'),
            items: [const DropdownMenuItem(value: null, child: Text('All')), for (final r in ProblemResult.values) DropdownMenuItem(value: r, child: Text(r.label))],
            onChanged: (v) => setState(() => result = v),
          ),
        ),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<String?>(
            initialValue: difficulty,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Difficulty'),
            items: [const DropdownMenuItem(value: null, child: Text('All')), for (final d in problemDifficulties) DropdownMenuItem(value: d, child: Text(d))],
            onChanged: (v) => setState(() => difficulty = v),
          ),
        ),
      ],
      SizedBox(
        width: 200,
        child: DropdownButtonFormField<String?>(
          key: ValueKey('pattern-$pattern'),
          initialValue: pattern,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Pattern'),
          items: [const DropdownMenuItem(value: null, child: Text('All')), for (final d in problemPatterns) DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))],
          onChanged: (v) => setState(() => pattern = v),
        ),
      ),
      if (view == _View.problems) FilterChip(label: const Text('Revision queue'), selected: revisionOnly, onSelected: (v) => setState(() => revisionOnly = v)),
    ]);
  }

  Widget _vault(Snapshot s, List<CodingProblem> list) {
    final withCode = list.where((p) => p.snippet.isNotEmpty).toList();
    if (withCode.isEmpty) {
      return const SizedBox(
          height: 260,
          child: EmptyState(
              icon: Icons.data_object_rounded,
              title: 'Your snippet vault is empty',
              message: 'Paste your solution into the "Solution code" field when logging a problem and it is saved here with syntax colours.'));
    }
    return Column(children: [
      for (final p in withCode)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SectionCard(
            title: p.title,
            trailing: IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: () => editProblem(context, ref, s, problem: p)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                Pill(p.difficulty, color: Palette.muted),
                if (p.pattern.isNotEmpty) Pill(p.pattern, color: Palette.brandBlue, icon: Icons.account_tree_outlined),
                Pill(p.language, color: Palette.muted, icon: Icons.code_rounded),
              ]),
              const SizedBox(height: 10),
              CodeView(p.snippet, language: p.language, maxLines: 16),
            ]),
          ),
        ),
    ]);
  }

  Widget _row(BuildContext context, Snapshot s, CodingProblem p) {
    final repo = ref.read(repoProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          onTap: () => editProblem(context, ref, s, problem: p),
          title: Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              Pill(p.result.label, color: resultColor(p.result)),
              Pill(p.difficulty, color: Palette.muted),
              if (p.pattern.isNotEmpty) Pill(p.pattern, color: Palette.brandBlue, icon: Icons.account_tree_outlined),
              Pill(p.platform, color: Palette.brandBlue),
              Pill(fmtMinutes(p.minutes), color: Palette.muted, icon: Icons.timer_outlined),
              if (_needsRevisit(p, s.today)) const Pill('Revise', color: Palette.warning, icon: Icons.replay),
              if (p.nextReview != null && p.nextReview!.isAfter(s.today)) Pill('Back on ${fmtDate(p.nextReview!)}', color: Palette.muted, icon: Icons.event_repeat_rounded),
              Pill(fmtDate(fromMs(p.attemptedAt)), color: Palette.muted),
            ]),
          ),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(tooltip: 'Time an attempt', icon: const Icon(Icons.timer_outlined), onPressed: () => showProblemTimer(context, p)),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (v) async {
                if (v == 'history') {
                  final attempts = await repo.attempts(problemId: p.id);
                  if (context.mounted) await showProblemHistory(context, p, attempts);
                } else if (v == 'delete') {
                  if (await confirm(context, 'Delete problem?', 'Remove "${p.title}" from your practice log?')) {
                    await repo.deleteProblem(p.id);
                  }
                }
              },
              itemBuilder: (c) => const [
                PopupMenuItem(value: 'history', child: Text('Solve-time history')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

/// Problems that are due to come back, with one-tap ways to retry or reschedule them.
class _ResurfaceCard extends ConsumerWidget {
  const _ResurfaceCard(this.queue, this.today);
  final List<CodingProblem> queue;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    final shown = queue.take(5).toList();
    return SectionCard(
      title: 'Resurfacing now (${queue.length})',
      trailing: const Text('Spaced revisits keep solutions fresh', style: TextStyle(color: Palette.muted, fontSize: 12)),
      child: Column(children: [
        for (final p in shown)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.replay_circle_filled_rounded, color: Palette.warning),
            title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
                p.nextReview != null && !p.nextReview!.isAfter(today)
                    ? 'Scheduled ${fmtDate(p.nextReview!)}'
                    : p.result == ProblemResult.needsRevision
                        ? 'Marked needs revision'
                        : 'Flagged for revision',
                style: const TextStyle(fontSize: 12)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton(onPressed: () => showProblemTimer(context, p), child: const Text('Retry')),
              PopupMenuButton<int>(
                tooltip: 'Done / remind me again',
                icon: const Icon(Icons.more_vert),
                onSelected: (d) => d == 0 ? repo.completeRevisit(p) : repo.completeRevisit(p, againInDays: d),
                itemBuilder: (c) => [
                  const PopupMenuItem(value: 0, child: Text('Mark as done')),
                  for (final d in revisitChoices) PopupMenuItem(value: d, child: Text('Done, remind me in $d days')),
                ],
              ),
            ]),
          ),
        if (queue.length > shown.length)
          Align(alignment: Alignment.centerLeft, child: Text('+ ${queue.length - shown.length} more in the list below', style: const TextStyle(color: Palette.muted, fontSize: 12.5))),
      ]),
    );
  }
}
