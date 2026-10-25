import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import '../../core/colors/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/app_database.dart';
import '../../core/services/weekly_review_service.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/format.dart';
import '../../core/utils/responsive.dart';
import '../utils/app_snack.dart';
import '../widgets/app_stat_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_layout.dart';
import '../widgets/section_card.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});
  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  int offset = 0; // weeks back

  @override
  Widget build(BuildContext context) {
    return ref.watch(snapshotProvider).when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
          data: (s) {
            final base = s.today.subtract(Duration(days: s.today.weekday - 1));
            final weekStart = base.subtract(Duration(days: 7 * offset));
            final r = WeeklyReview.build(s, weekStart);
            final compact = Responsive.isCompact(context);
            final weekEnd = weekStart.add(const Duration(days: 6));
            return PageBody(children: [
              PageHeader(title: 'Weekly Review', subtitle: 'Generated locally — works offline', actions: [
                IconButton.outlined(tooltip: 'Previous week', onPressed: () => setState(() => offset++), icon: const Icon(Icons.chevron_left)),
                Text('${DateFormat('d MMM').format(weekStart)} – ${DateFormat('d MMM').format(weekEnd)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton.outlined(tooltip: 'Next week', onPressed: offset == 0 ? null : () => setState(() => offset--), icon: const Icon(Icons.chevron_right)),
                OutlinedButton.icon(
                    onPressed: () async {
                      await _save(ref.read(dbProvider), r);
                      if (context.mounted) toast(context, 'Review saved');
                    },
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Save snapshot')),
              ]),
              AdaptiveGrid(minTile: compact ? 150 : 230, maxColumns: 4, minColumns: 2, children: [
                StatCard(label: 'Planned', value: '${fmtHours(r.plannedMinutes)} h', footer: 'scheduled this week', icon: Icons.event_note_rounded, colors: Grads.indigo),
                StatCard(label: 'Actual', value: '${fmtHours(r.actualMinutes)} h', footer: '${r.completedSessions} sessions', icon: Icons.timer_rounded, colors: Grads.emerald),
                StatCard(label: 'Missed', value: '${r.missedActivities}', footer: 'planned, not done', icon: Icons.event_busy_rounded, colors: Grads.red),
                StatCard(label: 'Milestones', value: '${r.milestonesDone.length}', footer: 'achieved', icon: Icons.emoji_events_rounded, colors: Grads.amber),
              ]),
              const SizedBox(height: 16),
              AdaptiveGrid(minTile: 420, maxColumns: 2, children: [
                SectionCard(title: 'Goals on track', child: _list(r.onTrack, 'No goals are confidently on track yet.', Icons.check_circle_outline, Palette.success)),
                SectionCard(title: 'Goals needing attention', child: _list(r.atRisk, 'Nothing at risk — nice.', Icons.warning_amber_rounded, Palette.warning)),
                SectionCard(title: 'Milestones achieved', child: _list(r.milestonesDone, 'No milestones completed this week.', Icons.emoji_events_outlined, Theme.of(context).colorScheme.primary)),
                SectionCard(title: 'Revision needed', child: _list(r.revisionTopics, 'No revision backlog.', Icons.replay, Palette.warning)),
              ]),
              const SizedBox(height: 16),
              SectionCard(title: 'Recommended priorities for next week', child: _list(r.priorities, '', Icons.bolt_rounded, Theme.of(context).colorScheme.primary)),
            ]);
          },
        );
  }

  Widget _list(List<String> items, String empty, IconData icon, Color color) {
    if (items.isEmpty) return Text(empty, style: const TextStyle(color: Palette.muted));
    return Column(children: [
      for (final i in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(i)),
          ]),
        ),
    ]);
  }

  Future<void> _save(AppDatabase db, WeeklyReviewData r) async {
    await db.db.insert(
        'weekly_reviews',
        {
          'id': newId(),
          'week_start': dateKey(r.weekStart),
          'payload': jsonEncode({
            'planned': r.plannedMinutes,
            'actual': r.actualMinutes,
            'sessions': r.completedSessions,
            'missed': r.missedActivities,
            'onTrack': r.onTrack,
            'atRisk': r.atRisk,
            'priorities': r.priorities,
          }),
          'created_at': nowMs(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
