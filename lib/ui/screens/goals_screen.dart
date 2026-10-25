import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/enums.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/responsive.dart';
import '../flows/goal_flow.dart';
import '../flows/roadmap_flow.dart';
import '../widgets/empty_state.dart';
import '../widgets/goal_board.dart';
import '../widgets/goal_card.dart';
import '../widgets/new_action_scope.dart';
import '../widgets/page_layout.dart';

enum GoalView { grid, list, board }

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});
  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  GoalView view = GoalView.grid;
  String query = '';
  GoalStatus? filter;
  String sort = 'deadline';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(snapshotProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(e),
      data: (s) {
        var goals = s.goals.where((g) => filter == null ? g.status != GoalStatus.archived : g.status == filter).toList();
        if (query.isNotEmpty) {
          final q = query.toLowerCase();
          goals = goals.where((g) => g.title.toLowerCase().contains(q) || g.tags.toLowerCase().contains(q)).toList();
        }
        goals.sort((a, b) => switch (sort) {
              'priority' => b.priority.compareTo(a.priority),
              'title' => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
              'updated' => b.updatedAt.compareTo(a.updatedAt),
              _ => (a.deadline ?? DateTime(2999)).compareTo(b.deadline ?? DateTime(2999)),
            });
        final compact = Responsive.isCompact(context);
        return NewActionScope(
          onNew: () => editGoal(context, ref, s),
          child: PageBody(children: [
            PageHeader(
              title: 'My Learning',
              subtitle: 'Goals, deadlines and progress',
              actions: [
                OutlinedButton.icon(
                    onPressed: () => importRoadmap(context, ref),
                    icon: const Icon(Icons.route_outlined),
                    label: const Text('Python roadmap')),
                FilledButton.icon(
                    onPressed: () => editGoal(context, ref, s),
                    icon: const Icon(Icons.add),
                    label: const Text('New goal')),
              ],
            ),
            Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(
                width: compact ? double.infinity : 280,
                child: TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search goals or tags'),
                    onChanged: (v) => setState(() => query = v)),
              ),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<GoalStatus?>(
                  initialValue: filter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Active')),
                    for (final st in GoalStatus.values) DropdownMenuItem(value: st, child: Text(st.label)),
                  ],
                  onChanged: (v) => setState(() => filter = v),
                ),
              ),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  initialValue: sort,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Sort by'),
                  items: const [
                    DropdownMenuItem(value: 'deadline', child: Text('Deadline')),
                    DropdownMenuItem(value: 'priority', child: Text('Priority')),
                    DropdownMenuItem(value: 'title', child: Text('Title')),
                    DropdownMenuItem(value: 'updated', child: Text('Recently updated')),
                  ],
                  onChanged: (v) => setState(() => sort = v!),
                ),
              ),
              SegmentedButton<GoalView>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: GoalView.grid, icon: Icon(Icons.grid_view_rounded), tooltip: 'Grid'),
                  ButtonSegment(value: GoalView.list, icon: Icon(Icons.view_list_rounded), tooltip: 'List'),
                  ButtonSegment(value: GoalView.board, icon: Icon(Icons.view_kanban_outlined), tooltip: 'Board'),
                ],
                selected: {view},
                onSelectionChanged: (v) => setState(() => view = v.first),
              ),
            ]),
            const SizedBox(height: 16),
            if (goals.isEmpty)
              SizedBox(
                height: 320,
                child: EmptyState(
                    icon: Icons.flag_outlined,
                    title: s.goals.isEmpty ? 'No goals yet' : 'No goals match',
                    message: s.goals.isEmpty
                        ? 'Create a goal to get deadline forecasts and a study plan.'
                        : 'Try clearing the search or status filter.',
                    action: s.goals.isEmpty
                        ? FilledButton(onPressed: () => editGoal(context, ref, s), child: const Text('Create goal'))
                        : null),
              )
            else
              switch (view) {
                GoalView.grid => AdaptiveGrid(
                    minTile: 320, maxColumns: 3, children: [for (final g in goals) GoalCard(g, s)]),
                GoalView.list => Column(children: [
                    for (final g in goals) Padding(padding: const EdgeInsets.only(bottom: 10), child: GoalCard(g, s, dense: true))
                  ]),
                GoalView.board => GoalBoard(goals, s),
              },
          ]),
        );
      },
    );
  }
}
