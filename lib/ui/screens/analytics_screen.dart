import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/colors/app_colors.dart';
import '../../core/models/coding_problem.dart';
import '../../core/models/enums.dart';
import '../../core/models/study_session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/goal_analyzer.dart';
import '../../core/services/streak_engine.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/format.dart';
import '../../core/utils/pickers.dart';
import '../../core/utils/responsive.dart';
import '../widgets/app_stat_card.dart';
import '../widgets/breakdown_bars.dart';
import '../widgets/charts/daily_hours_chart.dart';
import '../widgets/charts/planned_actual_chart.dart';
import '../widgets/charts/solved_trend_chart.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_layout.dart';
import '../widgets/section_card.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int days = 30;
  DateTimeRange? custom;
  String? subjectId, goalId;
  SessionType? type;

  @override
  Widget build(BuildContext context) {
    return ref.watch(snapshotProvider).when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
          data: (s) {
            final compact = Responsive.isCompact(context);
            final end = custom?.end ?? s.today;
            final start = custom?.start ?? end.subtract(Duration(days: days - 1));
            final endEx = dayOnly(end).add(const Duration(days: 1));
            bool inRange(int ms) {
              final d = fromMs(ms);
              return !d.isBefore(dayOnly(start)) && d.isBefore(endEx);
            }

            final sess = s.sessions.where((x) =>
                inRange(x.startedAt) &&
                (subjectId == null || x.subjectId == subjectId) &&
                (goalId == null || x.goalId == goalId) &&
                (type == null || x.type == type)).toList();
            // Problem time that is not already inside a linked session — no double counting.
            final probs = s.problems.where((p) =>
                p.sessionId == null &&
                inRange(p.attemptedAt) &&
                (subjectId == null || p.subjectId == subjectId) &&
                goalId == null &&
                (type == null || type == SessionType.codingPractice)).toList();
            final byDay = <String, int>{};
            for (final x in sess) {
              final k = dateKey(fromMs(x.startedAt));
              byDay[k] = (byDay[k] ?? 0) + x.activeSeconds ~/ 60;
            }
            for (final p in probs) {
              final k = dateKey(fromMs(p.attemptedAt));
              byDay[k] = (byDay[k] ?? 0) + p.minutes;
            }
            final total = byDay.values.fold<int>(0, (a, b) => a + b);
            final spanDays = dayOnly(end).difference(dayOnly(start)).inDays + 1;
            final activeDays = byDay.values.where((m) => m >= s.minQualifyingMinutes).length;
            final streak = StreakEngine.compute(s);

            final completed = s.goals.where((g) => g.status == GoalStatus.completed).toList();
            final onTime = completed.where((g) => g.deadline == null || !fromMs(g.updatedAt).isAfter(g.deadline!.add(const Duration(days: 1)))).length;
            final withDeadline = s.goals.where((g) => g.deadline != null).length;
            final estVsActual = completed.where((g) => (g.estimatedMinutes ?? 0) > 0).toList();
            final revisionBacklog = s.problems.where((p) => p.revisionRequired || p.result == ProblemResult.needsRevision).length +
                s.topics.where((t) => t.revisionStatus == 'due').length;

            return PageBody(children: [
              const PageHeader(title: 'Analytics', subtitle: 'Everything here is computed from your saved records'),
              Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7d')),
                    ButtonSegment(value: 30, label: Text('30d')),
                    ButtonSegment(value: 90, label: Text('90d')),
                  ],
                  selected: {custom == null ? days : -1},
                  emptySelectionAllowed: true,
                  onSelectionChanged: (v) => setState(() {
                    custom = null;
                    if (v.isNotEmpty) days = v.first;
                  }),
                ),
                OutlinedButton.icon(
                    onPressed: () async {
                      final r = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                          initialDateRange: custom ?? DateTimeRange(start: start, end: end));
                      if (r != null) setState(() => custom = r);
                    },
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(custom == null ? 'Custom range' : '${DateFormat('d MMM').format(custom!.start)} – ${DateFormat('d MMM').format(custom!.end)}')),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String?>(
                    initialValue: subjectId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Subject', isDense: true),
                    items: [const DropdownMenuItem(value: null, child: Text('All')), for (final e in subjectOptions(s).entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))],
                    onChanged: (v) => setState(() => subjectId = v),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String?>(
                    initialValue: goalId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Goal', isDense: true),
                    items: [const DropdownMenuItem(value: null, child: Text('All')), for (final g in s.goals) DropdownMenuItem(value: g.id, child: Text(g.title, overflow: TextOverflow.ellipsis))],
                    onChanged: (v) => setState(() => goalId = v),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<SessionType?>(
                    initialValue: type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Session type', isDense: true),
                    items: [const DropdownMenuItem(value: null, child: Text('All')), for (final t in SessionType.values) DropdownMenuItem(value: t, child: Text(t.label))],
                    onChanged: (v) => setState(() => type = v),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              AdaptiveGrid(minTile: compact ? 150 : 230, maxColumns: 4, minColumns: 2, children: [
                StatCard(label: 'Study hours', value: fmtHours(total), footer: 'in selected range', icon: Icons.schedule_rounded, colors: Grads.indigo),
                StatCard(label: 'Consistency', value: '${(activeDays * 100 / spanDays).round()}%', footer: '$activeDays of $spanDays days', icon: Icons.donut_large_rounded, colors: Grads.teal),
                StatCard(label: 'Longest streak', value: '${streak.longest} d', footer: 'Current ${streak.current} d', icon: Icons.local_fire_department_rounded, colors: Grads.red),
                StatCard(label: 'Revision backlog', value: '$revisionBacklog', footer: 'items to review', icon: Icons.replay_rounded, colors: Grads.orange),
              ]),
              const SizedBox(height: 16),
              AdaptiveGrid(minTile: 460, maxColumns: 2, children: [
                SectionCard(title: 'Study hours per day', child: DailyHoursChart(byDay, start, spanDays)),
                SectionCard(title: 'Planned vs actual (weekly)', child: PlannedActualChart(s)),
                SectionCard(title: 'Time by subject', child: BreakdownBars(_group(sess, probs, (x) => x.subjectId, (p) => p.subjectId, s.subjects.map((x) => MapEntry(x.id, (x.name, x.color))).toList()))),
                SectionCard(title: 'Time by goal', child: BreakdownBars(_group(sess, const [], (x) => x.goalId, (p) => null, s.goals.map((g) => MapEntry(g.id, (g.title, 0xFF2563EB))).toList()))),
                SectionCard(
                    title: 'Goals & deadlines',
                    child: Column(children: [
                      _kv('Goal completion rate', s.goals.isEmpty ? '—' : '${(completed.length * 100 / s.goals.length).round()}% (${completed.length}/${s.goals.length})'),
                      _kv('Deadline performance', withDeadline == 0 ? '—' : '$onTime of ${completed.length} completed on time'),
                      _kv('Estimated vs actual', estVsActual.isEmpty ? 'No completed goals with estimates' : '${fmtHours(estVsActual.fold<int>(0, (a, g) => a + g.estimatedMinutes!))}h est · ${fmtHours(estVsActual.fold<int>(0, (a, g) => a + s.goalMinutes(g.id)))}h actual'),
                      _kv('Personal calibration', '×${GoalAnalyzer.calibration(s).toStringAsFixed(2)}'),
                    ])),
                SectionCard(title: 'Coding activity (solved per week)', child: SolvedTrendChart(s)),
              ]),
            ]);
          },
        );
  }

  Widget _kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(k, style: const TextStyle(color: Palette.muted))),
        Flexible(child: Text(v, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700))),
      ]));

  List<(String, int, int)> _group(
      List<StudySession> sess,
      List<CodingProblem> probs,
      String? Function(StudySession) ks,
      String? Function(CodingProblem) kp,
      List<MapEntry<String, (String, int)>> meta) {
    final m = <String?, int>{};
    for (final x in sess) {
      m[ks(x)] = (m[ks(x)] ?? 0) + x.activeSeconds ~/ 60;
    }
    for (final p in probs) {
      m[kp(p)] = (m[kp(p)] ?? 0) + p.minutes;
    }
    final lookup = {for (final e in meta) e.key: e.value};
    return [
      for (final e in m.entries.where((e) => e.value > 0))
        (lookup[e.key]?.$1 ?? 'Unassigned', e.value, lookup[e.key]?.$2 ?? 0xFF94A3B8)
    ]..sort((a, b) => b.$2.compareTo(a.$2));
  }
}
