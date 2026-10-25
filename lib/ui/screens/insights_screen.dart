import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/colors/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/insights_engine.dart';
import '../../core/services/snapshot.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/format.dart';
import '../../core/utils/responsive.dart';
import '../utils/app_snack.dart';
import '../widgets/charts/insight_charts.dart';
import '../widgets/empty_state.dart';
import '../widgets/no_data.dart';
import '../widgets/page_layout.dart';
import '../widgets/pill.dart';
import '../widgets/progress_bar.dart';
import '../widgets/section_card.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});
  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  int? _year;

  @override
  Widget build(BuildContext context) {
    return ref.watch(snapshotProvider).when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
          data: (s) {
            if (s.sessions.isEmpty && s.problems.isEmpty && s.cardReviews.isEmpty) {
              return const EmptyState(
                  icon: Icons.lightbulb_outline_rounded,
                  title: 'Insights appear as you study',
                  message: 'Log a few sessions and Lumora will show your best study hour, your sharpest subjects and a yearly recap.');
            }
            final use24h = ref.watch(settingsProvider.select((x) => x.use24h));
            final hours = InsightsEngine.hours(s);
            final subjects = InsightsEngine.focusBySubject(s);
            final burnout = InsightsEngine.burnout(s);
            final years = ({
              for (final x in s.sessions) fromMs(x.startedAt).year,
              for (final p in s.problems) fromMs(p.attemptedAt).year,
              for (final r in s.cardReviews) fromMs(r.reviewedAt).year,
              s.today.year,
            }.toList()
              ..sort((a, b) => b.compareTo(a)));
            final year = _year ?? years.first;
            final review = InsightsEngine.yearInReview(s, year);
            return PageBody(maxWidth: 1200, children: [
              const PageHeader(title: 'Study Insights', subtitle: 'What your own data says about how you learn'),
              _BurnoutCard(burnout),
              const SizedBox(height: 16),
              AdaptiveGrid(minTile: 520, maxColumns: 2, spacing: 16, children: [
                _HoursCard(hours, use24h),
                _SubjectFocusCard(subjects),
              ]),
              const SizedBox(height: 16),
              _YearCard(
                review: review,
                years: years,
                onYear: (y) => setState(() => _year = y),
                use24h: use24h,
                s: s,
              ),
            ]);
          },
        );
  }
}

// ----------------------------------------------------------------- burnout ---

class _BurnoutCard extends StatelessWidget {
  const _BurnoutCard(this.r);
  final BurnoutReport r;

  @override
  Widget build(BuildContext context) {
    final (color, icon, title) = switch (r.level) {
      BurnoutLevel.none => (Palette.success, Icons.spa_rounded, 'Healthy pace'),
      BurnoutLevel.watch => (Palette.warning, Icons.visibility_rounded, 'Keep an eye on your pace'),
      BurnoutLevel.high => (Palette.danger, Icons.warning_amber_rounded, 'Burnout risk: slow down'),
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Text(r.advice),
            for (final reason in r.reasons)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.circle, size: 6, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(reason, style: const TextStyle(color: Palette.muted))),
                ]),
              ),
            const SizedBox(height: 8),
            Text('Last 7 days: ${fmtMinutes(r.last7Minutes)} · usual week: ${fmtMinutes(r.baselineWeekMinutes)}',
                style: const TextStyle(color: Palette.muted, fontSize: 12.5)),
          ]),
        ),
      ]),
    );
  }
}

// ----------------------------------------------------------------- hours ---

class _HoursCard extends StatelessWidget {
  const _HoursCard(this.h, this.use24h);
  final HourInsight h;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final best = h.bestHour;
    return SectionCard(
      title: 'Best time to study',
      trailing: const Text('last 90 days', style: TextStyle(color: Palette.muted, fontSize: 12)),
      child: best == null
          ? const NoData()
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                Pill('Most study: ${fmtHourOfDay(best, use24h: use24h)}', color: Theme.of(context).colorScheme.primary, icon: Icons.schedule_rounded),
                if (h.sharpestHour != null)
                  Pill('Sharpest focus: ${fmtHourOfDay(h.sharpestHour!, use24h: use24h)} (${h.sharpestRating!.toStringAsFixed(1)}/5)',
                      color: Palette.success, icon: Icons.bolt_rounded),
              ]),
              const SizedBox(height: 14),
              HourOfDayChart(minutes: h.minutes, bestHour: best, use24h: use24h),
              const SizedBox(height: 10),
              Text(
                  h.sharpestHour != null && h.sharpestHour != best
                      ? 'You study most around ${fmtHourOfDay(best, use24h: use24h)}, but you rate your focus highest around ${fmtHourOfDay(h.sharpestHour!, use24h: use24h)}. Try moving your hardest topic there.'
                      : 'Schedule your most demanding topic around ${fmtHourOfDay(best, use24h: use24h)} when you already study the most.',
                  style: const TextStyle(color: Palette.muted)),
              if (h.sharpestHour == null)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Rate your focus when you finish sessions to find your sharpest hour.',
                      style: TextStyle(color: Palette.muted, fontSize: 12.5)),
                ),
            ]),
    );
  }
}

// -------------------------------------------------------- focus vs subject ---

class _SubjectFocusCard extends StatelessWidget {
  const _SubjectFocusCard(this.rows);
  final List<SubjectFocus> rows;

  @override
  Widget build(BuildContext context) {
    final rated = rows.where((r) => r.avgRating != null).toList();
    final top = rated.isEmpty ? null : (rated.toList()..sort((a, b) => b.avgRating!.compareTo(a.avgRating!))).first;
    final low = rated.length < 2 ? null : (rated.toList()..sort((a, b) => a.avgRating!.compareTo(b.avgRating!))).first;
    return SectionCard(
      title: 'Focus by subject',
      trailing: const Text('last 90 days', style: TextStyle(color: Palette.muted, fontSize: 12)),
      child: rows.isEmpty
          ? const NoData()
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final r in rows.take(8))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: Color(r.color), shape: BoxShape.circle)),
                      Expanded(child: Text(r.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text(r.avgRating == null ? 'not rated' : '${r.avgRating!.toStringAsFixed(1)} / 5',
                          style: TextStyle(fontWeight: FontWeight.w700, color: r.avgRating == null ? Palette.muted : Color(r.color))),
                    ]),
                    const SizedBox(height: 4),
                    ProgressBar((r.avgRating ?? 0) / 5, color: Color(r.color), height: 6),
                    const SizedBox(height: 3),
                    Text('${fmtMinutes(r.minutes)} · ${r.sessions} sessions · ${fmtMinutes(r.avgSessionMinutes)} avg',
                        style: const TextStyle(color: Palette.muted, fontSize: 12)),
                  ]),
                ),
              if (top != null) ...[
                const Divider(height: 24),
                Text(
                    low != null && low.subjectId != top.subjectId
                        ? 'You focus best on ${top.name} and find ${low.name} hardest to concentrate on. Try shorter blocks or an earlier slot for ${low.name}.'
                        : 'You focus best on ${top.name}.',
                    style: const TextStyle(color: Palette.muted)),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Rate your sessions (1–5) to compare focus across subjects.', style: TextStyle(color: Palette.muted, fontSize: 12.5)),
                ),
            ]),
    );
  }
}

// ---------------------------------------------------------- year in review ---

class _YearCard extends StatelessWidget {
  const _YearCard({required this.review, required this.years, required this.onYear, required this.use24h, required this.s});
  final YearReview review;
  final List<int> years;
  final ValueChanged<int> onYear;
  final bool use24h;
  final Snapshot s;

  String get _summary {
    final r = review;
    final month = r.busiestMonth == null ? null : DateFormat.MMMM().format(DateTime(r.year, r.busiestMonth!));
    return [
      'My ${r.year} in Lumora',
      '${fmtHours(r.minutes)} hours across ${r.sessions} sessions on ${r.activeDays} active days',
      'Longest streak: ${r.longestStreak} days',
      if (r.topSubject != null) 'Top subject: ${r.topSubject} (${fmtHours(r.topSubjectMinutes)} h)',
      if (month != null) 'Busiest month: $month',
      '${r.problemsSolved} problems solved, ${r.cardsReviewed} flashcard reviews',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final r = review;
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [primary, Color.lerp(primary, const Color(0xFF312E81), 0.6)!]),
        boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      padding: EdgeInsets.all(Responsive.isCompact(context) ? 18 : 28),
      child: Theme(
        data: Theme.of(context).copyWith(brightness: Brightness.dark),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_awesome_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text('${r.year} in review', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700))),
            if (years.length > 1)
              PopupMenuButton<int>(
                tooltip: 'Choose year',
                icon: const Icon(Icons.expand_more_rounded, color: Colors.white),
                onSelected: onYear,
                itemBuilder: (c) => [for (final y in years) PopupMenuItem(value: y, child: Text('$y'))],
              ),
            IconButton(
              tooltip: 'Copy summary',
              icon: const Icon(Icons.copy_rounded, color: Colors.white),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _summary));
                if (context.mounted) toast(context, 'Summary copied');
              },
            ),
          ]),
          const SizedBox(height: 16),
          if (!r.hasData)
            const Text('Nothing recorded this year yet.', style: TextStyle(color: Colors.white70))
          else ...[
            Wrap(spacing: 12, runSpacing: 12, children: [
              _Big('${fmtHours(r.minutes)} h', 'learning time', Icons.schedule_rounded),
              _Big('${r.sessions}', 'sessions', Icons.timer_rounded),
              _Big('${r.activeDays}', 'active days', Icons.event_available_rounded),
              _Big('${r.longestStreak} d', 'longest streak', Icons.local_fire_department_rounded),
              _Big('${r.problemsSolved}', 'problems solved', Icons.code_rounded),
              _Big('${r.cardsReviewed}', 'card reviews', Icons.style_rounded),
              if (r.goalsCompleted > 0) _Big('${r.goalsCompleted}', 'goals completed', Icons.flag_rounded),
            ]),
            const SizedBox(height: 20),
            MonthChart(minutes: r.monthMinutes, highlight: r.busiestMonth),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (r.topSubject != null) _Chip('Top subject: ${r.topSubject}'),
              if (r.busiestMonth != null) _Chip('Busiest month: ${DateFormat.MMMM().format(DateTime(r.year, r.busiestMonth!))}'),
              if (r.bestWeekday != null) _Chip('Best day: ${DateFormat.EEEE().format(DateTime(2024, 1, r.bestWeekday!))}'),
              if (r.bestHour != null) _Chip('Favourite hour: ${fmtHourOfDay(r.bestHour!, use24h: use24h)}'),
              if (r.longestSessionMinutes > 0) _Chip('Longest session: ${fmtMinutes(r.longestSessionMinutes)}'),
              if (r.avgRating != null) _Chip('Average focus: ${r.avgRating!.toStringAsFixed(1)} / 5'),
              if (r.hardSolved > 0) _Chip('${r.hardSolved} hard problems solved'),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big(this.value, this.label, this.icon);
  final String value, label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 130),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(Radii.md)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
      );
}
