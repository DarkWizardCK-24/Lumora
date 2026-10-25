import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors/app_colors.dart';
import '../../core/colors/status_colors.dart';
import '../../core/models/enums.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/coach_service.dart';
import '../../core/services/goal_analyzer.dart';
import '../../core/utils/responsive.dart';
import '../widgets/analysis_panel.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_layout.dart';
import '../widgets/section_card.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});
  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  String? selected;

  @override
  Widget build(BuildContext context) {
    return ref.watch(snapshotProvider).when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
          data: (s) {
            final goals = s.goals.where((g) => g.status != GoalStatus.archived).toList();
            if (goals.isEmpty) {
              return const EmptyState(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Nothing to analyse yet',
                  message: 'Create a goal with a deadline and Lumora will forecast whether you can finish it.');
            }
            final cur = goals.where((g) => g.id == selected).firstOrNull ?? goals.first;
            final analyses = [for (final g in goals) GoalAnalyzer.analyze(g, s)];
            final a = analyses.firstWhere((x) => x.goal.id == cur.id);
            final tips = ref.watch(tipsProvider).value ?? const <Tip>[];
            return PageBody(children: [
              const PageHeader(
                  title: 'Smart Analysis',
                  subtitle: 'Deterministic, explainable forecasts computed on this device from your own records'),
              AdaptiveGrid(minTile: 220, maxColumns: 4, minColumns: 2, children: [
                for (final st in [DeadlineStatus.onTrack, DeadlineStatus.adjustments, DeadlineStatus.atRisk, DeadlineStatus.unlikely])
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(width: 6, height: 38, decoration: BoxDecoration(color: deadlineColor(st), borderRadius: BorderRadius.circular(4))),
                        const SizedBox(width: 12),
                        Expanded(child: Text(st.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                        Text('${analyses.where((x) => x.status == st).length}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
              ]),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: cur.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Goal to analyse'),
                items: [for (final g in goals) DropdownMenuItem(value: g.id, child: Text(g.title, overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setState(() => selected = v),
              ),
              const SizedBox(height: 16),
              AnalysisPanel(a, s),
              if (tips.isNotEmpty) ...[
                const SizedBox(height: 16),
                SectionCard(title: 'Coach', child: Column(children: [for (final t in tips) _TipRow(t)])),
              ],
            ]);
          },
        );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow(this.t);
  final Tip t;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.lightbulb_outline_rounded, color: Palette.warning),
        title: Text(t.title),
        subtitle: Text('${t.why} ${t.recommendation}'),
      );
}
