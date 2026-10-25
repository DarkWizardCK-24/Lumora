import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/achievement_engine.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/format.dart';
import '../flows/milestone_flow.dart';
import '../widgets/empty_state.dart';
import '../widgets/milestone_tile.dart';
import '../widgets/new_action_scope.dart';
import '../widgets/page_layout.dart';
import '../widgets/section_card.dart';

class MilestonesScreen extends ConsumerWidget {
  const MilestonesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(snapshotProvider).when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
          data: (s) {
            final open = s.milestones.where((m) => !m.done).toList();
            final done = s.milestones.where((m) => m.done).toList();
            final earned = ref.watch(achievementsProvider).value ?? const <String, int>{};
            return NewActionScope(
              onNew: () => editMilestone(context, ref, s),
              child: PageBody(children: [
                PageHeader(title: 'Milestones', subtitle: '${open.length} open · ${done.length} completed', actions: [
                  FilledButton.icon(
                      onPressed: () => editMilestone(context, ref, s),
                      icon: const Icon(Icons.add),
                      label: const Text('New milestone')),
                ]),
                if (s.milestones.isEmpty)
                  const SizedBox(
                      height: 260,
                      child: EmptyState(
                          icon: Icons.emoji_events_outlined,
                          title: 'No milestones yet',
                          message: 'Milestones turn a big goal into checkpoints you can finish.'))
                else ...[
                  SectionCard(
                      title: 'Open',
                      child: open.isEmpty
                          ? const Text('Everything is complete.')
                          : Column(children: [for (final m in open) MilestoneTile(m, s, showGoal: true)])),
                  const SizedBox(height: 16),
                  if (done.isNotEmpty)
                    SectionCard(title: 'Completed', child: Column(children: [for (final m in done) MilestoneTile(m, s, showGoal: true)])),
                ],
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Achievements',
                  child: Column(children: [
                    for (final d in achievementDefs)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(earned.containsKey(d.code) ? Icons.workspace_premium_rounded : Icons.lock_outline,
                            color: earned.containsKey(d.code) ? Palette.warning : Palette.muted),
                        title: Text(d.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(d.description),
                        trailing: earned.containsKey(d.code) ? Text(fmtDate(fromMs(earned[d.code]!))) : null,
                      ),
                  ]),
                ),
              ]),
            );
          },
        );
  }
}
