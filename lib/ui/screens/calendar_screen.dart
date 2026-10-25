import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/colors/app_colors.dart';
import '../../core/colors/status_colors.dart';
import '../../core/models/enums.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/snapshot.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/format.dart';
import '../../core/utils/responsive.dart';
import '../flows/activity_flow.dart';
import '../widgets/calendar_agenda_view.dart';
import '../widgets/calendar_day_list.dart';
import '../widgets/calendar_item.dart';
import '../widgets/calendar_month_view.dart';
import '../widgets/calendar_week_view.dart';
import '../widgets/empty_state.dart';
import '../widgets/new_action_scope.dart';
import '../widgets/page_layout.dart';
import '../widgets/section_card.dart';

enum CalView { month, week, day, agenda }

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalView? view;
  DateTime focus = dayOnly(DateTime.now());
  DateTime selected = dayOnly(DateTime.now());

  List<CalendarItem> _items(Snapshot s) => [
        for (final a in s.activities)
          CalendarItem(a.start, a.title, a.done ? Palette.muted : activityKindColor(a.kind), a.done ? Icons.check_circle : Icons.circle_outlined,
              activity: a, sub: '${DateFormat.jm().format(a.start)} · ${fmtMinutes(a.plannedMinutes)} · ${a.kind.label}'),
        for (final g in s.goals.where((g) => g.deadline != null && g.status != GoalStatus.completed && !g.archived))
          CalendarItem(g.deadline!, 'Deadline: ${g.title}', Palette.danger, Icons.flag_rounded, sub: 'Goal deadline'),
        for (final m in s.milestones.where((m) => m.dueDate != null && !m.done))
          CalendarItem(m.dueDate!, 'Milestone: ${m.title}', const Color(0xFFD97706), Icons.emoji_events_rounded, sub: 'Milestone due'),
      ];

  void _shift(int dir) {
    setState(() {
      final v = view ?? CalView.month;
      focus = switch (v) {
        CalView.month => DateTime(focus.year, focus.month + dir, 1),
        CalView.week => focus.add(Duration(days: 7 * dir)),
        CalView.day => focus.add(Duration(days: dir)),
        CalView.agenda => focus.add(Duration(days: 14 * dir)),
      };
      if (v == CalView.day) selected = focus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(snapshotProvider).when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
          data: (s) {
            final compact = Responsive.isCompact(context);
            final v = view ?? (compact ? CalView.agenda : CalView.month);
            final items = _items(s);
            final title = switch (v) {
              CalView.month => DateFormat('MMMM yyyy').format(focus),
              CalView.week => 'Week of ${DateFormat('d MMM').format(_weekStart(focus))}',
              CalView.day => DateFormat('EEE, d MMM yyyy').format(focus),
              CalView.agenda => 'Next 14 days from ${DateFormat('d MMM').format(focus)}',
            };
            return NewActionScope(
              onNew: () => editActivity(context, ref, s, day: selected),
              child: PageBody(children: [
                PageHeader(title: 'Calendar & Planner', subtitle: 'Planned time is tracked separately from actual study time', actions: [
                  FilledButton.icon(
                      onPressed: () => editActivity(context, ref, s, day: selected),
                      icon: const Icon(Icons.add),
                      label: const Text('Schedule')),
                ]),
                Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  IconButton.outlined(tooltip: 'Previous', onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
                  IconButton.outlined(tooltip: 'Next', onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
                  OutlinedButton(onPressed: () => setState(() => focus = selected = dayOnly(DateTime.now())), child: const Text('Today')),
                  ConstrainedBox(constraints: const BoxConstraints(maxWidth: 260), child: Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  SegmentedButton<CalView>(
                    showSelectedIcon: false,
                    segments: [
                      for (final c in CalView.values) ButtonSegment(value: c, label: Text(compact ? c.name[0].toUpperCase() : c.name[0].toUpperCase() + c.name.substring(1))),
                    ],
                    selected: {v},
                    onSelectionChanged: (x) => setState(() => view = x.first),
                  ),
                ]),
                const SizedBox(height: 16),
                switch (v) {
                  CalView.month => CalendarMonthView(focus, selected, items, s, compact, (d) => setState(() => selected = d)),
                  CalView.week => CalendarWeekView(_weekStart(focus), items, s, compact),
                  CalView.day => SectionCard(child: CalendarDayList(focus, items, s)),
                  CalView.agenda => CalendarAgendaView(focus, items, s),
                },
                if (v == CalView.month) ...[
                  const SizedBox(height: 16),
                  SectionCard(title: DateFormat('EEEE, d MMMM').format(selected), child: CalendarDayList(selected, items, s)),
                ],
              ]),
            );
          },
        );
  }

  DateTime _weekStart(DateTime d) => dayOnly(d).subtract(Duration(days: d.weekday - 1));
}
