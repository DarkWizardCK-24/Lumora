import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/colors/app_colors.dart';
import '../../core/colors/status_colors.dart';
import '../../core/services/goal_analyzer.dart';
import '../../core/services/snapshot.dart';
import '../../core/utils/format.dart';
import '../../core/utils/responsive.dart';
import '../flows/schedule_flow.dart';
import 'pill.dart';
import 'section_card.dart';

String _dateOrDash(DateTime? d) => d == null ? '—' : fmtDate(d);

/// Reusable panel showing a goal's forecast, feasibility, risks and plan actions.
class AnalysisPanel extends ConsumerWidget {
  const AnalysisPanel(this.a, this.s, {super.key});
  final GoalAnalysis a;
  final Snapshot s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = deadlineColor(a.status);
    final compact = Responsive.isCompact(context);
    Widget metric(String l, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: const TextStyle(color: Palette.muted, fontSize: 12)),
          const SizedBox(height: 2),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ]);
    return SectionCard(
      title: 'Analysis · ${a.goal.title}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          Pill(a.status.label, color: color),
          Pill('Confidence: ${a.confidence.name}', color: Palette.muted, icon: Icons.verified_outlined),
          Pill(a.estimateSource, color: Palette.brandBlue),
        ]),
        const SizedBox(height: 16),
        if (a.remainingMinutes == null) ...[
          Text(a.nextAction),
          const SizedBox(height: 8),
          for (final r in a.risks) Text('• $r', style: const TextStyle(color: Palette.muted)),
        ] else ...[
          AdaptiveGrid(minTile: compact ? 140 : 190, maxColumns: 4, minColumns: 2, spacing: 16, children: [
            metric('Remaining effort', fmtDuration(a.remainingMinutes!)),
            metric('Logged so far', fmtDuration(a.loggedMinutes)),
            metric('Available capacity', a.goal.deadline == null ? 'No deadline' : fmtDuration(a.capacityMinutes)),
            metric('Study days left', a.goal.deadline == null ? '—' : '${a.studyDaysLeft}'),
            metric('Required / day', a.requiredDaily == null ? '—' : fmtDuration(a.requiredDaily!)),
            metric('Required / week', a.requiredWeekly == null ? '—' : fmtDuration(a.requiredWeekly!)),
            metric('Workload gap', a.gapMinutes == 0 ? 'None' : fmtDuration(a.gapMinutes)),
            metric('Deadline', _dateOrDash(a.goal.deadline)),
          ]),
          const SizedBox(height: 16),
          const Text('Projected completion', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          AdaptiveGrid(minTile: 170, maxColumns: 3, minColumns: 1, spacing: 10, children: [
            _Forecast('Optimistic', a.optimistic, Palette.success, a.goal.deadline),
            _Forecast('Realistic', a.realistic, Palette.brandBlue, a.goal.deadline),
            _Forecast('Conservative', a.conservative, Palette.warning, a.goal.deadline),
          ]),
          if (a.calibration != 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Personal calibration ×${a.calibration.toStringAsFixed(2)} applied from completed goals.',
                  style: const TextStyle(color: Palette.muted, fontSize: 12)),
            ),
          if (a.confidence == Confidence.low)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Low confidence — add an effort estimate or milestones for a firmer forecast.',
                  style: TextStyle(color: Palette.warning)),
            ),
          if (a.risks.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Risks', style: TextStyle(fontWeight: FontWeight.w700)),
            for (final r in a.risks)
              Padding(padding: const EdgeInsets.only(top: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: Palette.warning),
                const SizedBox(width: 8),
                Expanded(child: Text(r)),
              ])),
          ],
          if (a.alternatives.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Realistic alternatives', style: TextStyle(fontWeight: FontWeight.w700)),
            for (final r in a.alternatives)
              Padding(padding: const EdgeInsets.only(top: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.arrow_right_alt_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(r)),
              ])),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(Radii.md)),
            child: Row(children: [
              Icon(Icons.bolt_rounded, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text('Next: ${a.nextAction}', style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [
          if (a.remainingMinutes != null && a.status != DeadlineStatus.completed)
            FilledButton.icon(
                onPressed: () => previewSchedule(context, ref, s, a.goal),
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: const Text('Generate / revise plan')),
          OutlinedButton.icon(
              onPressed: () => context.go('/goals/${a.goal.id}'),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open goal')),
        ]),
      ]),
    );
  }
}

class _Forecast extends StatelessWidget {
  const _Forecast(this.label, this.date, this.color, this.deadline);
  final String label;
  final DateTime? date;
  final Color color;
  final DateTime? deadline;
  @override
  Widget build(BuildContext context) {
    final late = date != null && deadline != null && date!.isAfter(deadline!);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 4),
        Text(_dateOrDash(date), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        if (deadline != null)
          Text(late ? 'after deadline' : 'before deadline',
              style: TextStyle(color: late ? Palette.danger : Palette.success, fontSize: 12)),
      ]),
    );
  }
}
