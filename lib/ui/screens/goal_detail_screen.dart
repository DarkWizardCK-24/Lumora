import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/colors/app_colors.dart';
import '../../core/models/enums.dart';
import '../../core/models/goal.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/goal_analyzer.dart';
import '../../core/services/repository.dart';
import '../../core/services/snapshot.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/format.dart';
import '../../core/utils/pickers.dart';
import '../../core/utils/responsive.dart';
import '../flows/goal_flow.dart';
import '../flows/milestone_flow.dart';
import '../utils/app_snack.dart';
import '../widgets/analysis_panel.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/form_dialog.dart';
import '../widgets/milestone_tile.dart';
import '../widgets/page_layout.dart';
import '../widgets/pill.dart';
import '../widgets/progress_bar.dart';
import '../widgets/section_card.dart';

class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({super.key, required this.goalId});
  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(snapshotProvider).when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
          data: (s) {
            final g = s.goals.where((x) => x.id == goalId).firstOrNull;
            if (g == null) {
              return EmptyState(
                  icon: Icons.search_off,
                  title: 'Goal not found',
                  message: 'It may have been deleted.',
                  action: FilledButton(onPressed: () => context.go('/goals'), child: const Text('Back to goals')));
            }
            final a = GoalAnalyzer.analyze(g, s);
            final repo = ref.read(repoProvider);
            final milestones = s.milestones.where((m) => m.goalId == g.id).toList();
            final topics = s.topics.where((t) => t.goalId == g.id).toList();
            final sessions = s.sessions.where((x) => x.goalId == g.id).take(8).toList();
            final subj = subjectNameOf(s, g.subjectId);
            final subjObj = s.subjects.where((x) => x.id == g.subjectId).firstOrNull;
            return PageBody(children: [
              Row(children: [
                TextButton.icon(
                    onPressed: () => context.go('/goals'),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('All goals')),
                const Spacer(),
                if (subjObj != null)
                  Hero(
                    tag: 'goal-icon-${g.id}',
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Color(subjObj.color).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                      child: Icon(iconFor(subjObj.icon), size: 22, color: Color(subjObj.color)),
                    ),
                  ),
              ]),
              PageHeader(title: g.title, subtitle: [?subj, g.status.label].join(' · '), actions: [
                OutlinedButton.icon(
                    onPressed: () => editGoal(context, ref, s, goal: g),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit')),
                if (g.status != GoalStatus.completed)
                  FilledButton.icon(
                      onPressed: () async {
                        g
                          ..status = GoalStatus.completed
                          ..manualProgress = 100;
                        await repo.saveGoal(g);
                        await repo.award('first-goal');
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Mark complete')),
                IconButton(
                  tooltip: 'Delete goal',
                  color: Palette.danger,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await confirm(
                        context,
                        'Delete this goal?',
                        'Its ${milestones.length} milestones and planned activities will be deleted. '
                            'Study sessions, notes and topics are kept and simply unlinked from the goal.');
                    if (ok) {
                      await repo.deleteGoal(g.id);
                      if (context.mounted) context.go('/goals');
                    }
                  },
                ),
              ]),
              SectionCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: ProgressBar(a.progress, height: 12)),
                  const SizedBox(width: 12),
                  Text('${(a.progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                ]),
                const SizedBox(height: 6),
                Text(g.manualProgress != null
                    ? 'Progress is set manually and is never overwritten automatically.'
                    : 'Progress is calculated from completed milestones and topics — time spent alone is not counted as mastery.',
                    style: const TextStyle(color: Palette.muted, fontSize: 12)),
                if (g.description.isNotEmpty) ...[const SizedBox(height: 12), Text(g.description)],
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  Pill('Level ${g.currentLevel} → ${g.targetLevel}', color: Theme.of(context).colorScheme.primary),
                  Pill(g.deadline == null ? 'No deadline' : 'Due ${fmtDate(g.deadline!)}', color: Palette.brandBlue),
                  Pill('${priorityLabels[g.priority]} priority', color: Palette.muted),
                  for (final t in g.tagList) Pill('#$t', color: Palette.muted),
                ]),
                if (g.criteria.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Completion criteria', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(g.criteria),
                ],
              ])),
              const SizedBox(height: 16),
              AnalysisPanel(a, s),
              const SizedBox(height: 16),
              AdaptiveGrid(minTile: 460, maxColumns: 2, children: [
                SectionCard(
                  title: 'Milestone timeline',
                  trailing: TextButton.icon(
                      onPressed: () => editMilestone(context, ref, s, goalId: g.id),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add')),
                  child: milestones.isEmpty
                      ? const Text('Break the goal into milestones with due dates.', style: TextStyle(color: Palette.muted))
                      : Column(children: [for (final m in milestones) MilestoneTile(m, s)]),
                ),
                SectionCard(
                  title: 'Linked topics',
                  trailing: TextButton.icon(
                      onPressed: () => _linkTopic(context, ref, s, g),
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('Link')),
                  child: topics.isEmpty
                      ? const Text('Link topics from your subjects to track evidence-based progress.',
                          style: TextStyle(color: Palette.muted))
                      : Column(children: [
                          for (final t in topics)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: t.status == 'done',
                              title: Text(t.name),
                              subtitle: Text('${fmtMinutes(t.estimatedMinutes)} estimated'),
                              secondary: IconButton(
                                  tooltip: 'Unlink',
                                  icon: const Icon(Icons.link_off, size: 18),
                                  onPressed: () {
                                    t.goalId = null;
                                    repo.saveTopic(t);
                                  }),
                              onChanged: (v) {
                                t.status = v == true ? 'done' : 'todo';
                                repo.saveTopic(t);
                              },
                            ),
                        ]),
                ),
                SectionCard(
                  title: 'Recent sessions',
                  child: sessions.isEmpty
                      ? const Text('No sessions logged against this goal yet.', style: TextStyle(color: Palette.muted))
                      : Column(children: [
                          for (final x in sessions)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.timer_outlined, color: Theme.of(context).colorScheme.primary),
                              title: Text('${x.type.label} · ${fmtMinutes(x.activeSeconds / 60)}'),
                              subtitle: Text(fmtDateTime(fromMs(x.startedAt))),
                            ),
                        ]),
                ),
                SectionCard(
                  title: 'Progress history',
                  child: Column(children: [
                    _kv('Created', fmtDate(fromMs(g.createdAt))),
                    _kv('Started', fmtDate(g.startDate)),
                    _kv('Last updated', fmtDateTime(fromMs(g.updatedAt))),
                    _kv('Time logged', fmtMinutes(a.loggedMinutes)),
                    _kv('Milestones', '${milestones.where((m) => m.done).length}/${milestones.length} done'),
                  ]),
                ),
              ]),
            ]);
          },
        );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(k, style: const TextStyle(color: Palette.muted))),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );

  Future<void> _linkTopic(BuildContext context, WidgetRef ref, Snapshot s, Goal g) async {
    final avail = s.topics.where((t) => t.goalId == null && (g.subjectId == null || t.subjectId == g.subjectId)).toList();
    if (avail.isEmpty) {
      toast(context, 'No unlinked topics${g.subjectId == null ? '' : ' in this goal\'s subject'}. Add topics under Subjects first.');
      return;
    }
    final v = await showForm(context,
        title: 'Link a topic',
        fields: [FChoice('topic', 'Topic', {for (final t in avail) t.id: t.name})],
        submitLabel: 'Link');
    final id = v?['topic'] as String?;
    if (id == null) return;
    final t = avail.firstWhere((x) => x.id == id);
    t.goalId = g.id;
    await ref.read(repoProvider).saveTopic(t);
  }
}
