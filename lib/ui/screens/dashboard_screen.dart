import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/colors/app_colors.dart';
import '../../core/models/enums.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/coach_service.dart';
import '../../core/services/goal_analyzer.dart';
import '../../core/services/snapshot.dart';
import '../../core/services/streak_engine.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/format.dart';
import '../../core/utils/responsive.dart';
import '../widgets/app_stat_card.dart';
import '../widgets/charts/streak_heatmap.dart';
import '../widgets/charts/subject_pie_chart.dart';
import '../widgets/charts/weekly_activity_chart.dart';
import '../widgets/daily_goal_card.dart';
import '../widgets/level_card.dart';
import '../widgets/deadlines_list.dart';
import '../widgets/empty_state.dart';
import '../widgets/goal_progress_list.dart';
import '../widgets/next_action_card.dart';
import '../widgets/onboarding_card.dart';
import '../widgets/page_layout.dart';
import '../widgets/quick_actions_bar.dart';
import '../widgets/recent_activity_list.dart';
import '../widgets/section_card.dart';
import '../widgets/start_session_card.dart';
import '../widgets/tip_card.dart';
import '../widgets/today_plan_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(snapshotProvider);
    return snapAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(e),
      data: (s) => _Dashboard(s),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard(this.s);
  final Snapshot s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = Responsive.isCompact(context);
    final settings = ref.watch(settingsProvider);
    final tips = ref.watch(tipsProvider).value ?? const <Tip>[];
    final streak = StreakEngine.compute(s);
    final xp = ref.watch(xpProvider);
    final weekStart = s.today.subtract(Duration(days: s.today.weekday - 1));
    final weekMin = s.minutesBetween(weekStart, weekStart.add(const Duration(days: 7)));
    final todayMin = s.minutesOn(s.today);
    final analyses = [
      for (final g in s.goals.where((g) => !g.archived && g.status != GoalStatus.archived))
        GoalAnalyzer.analyze(g, s)
    ];
    final active = s.goals.where((g) => g.status == GoalStatus.inProgress || g.status == GoalStatus.notStarted).length;
    final completed = s.goals.where((g) => g.status == GoalStatus.completed).length;
    final solved = s.problems.where((p) => p.result == ProblemResult.solved).length;
    final msDone = s.milestones.where((m) => m.done).length;
    final atRisk = analyses
        .where((a) => a.status == DeadlineStatus.atRisk || a.status == DeadlineStatus.unlikely || a.status == DeadlineStatus.passed)
        .length;
    final empty = s.goals.isEmpty && s.subjects.isEmpty && s.sessions.isEmpty;

    final stats = AdaptiveGrid(
      minTile: compact ? 150 : 220,
      maxColumns: 5,
      minColumns: 2,
      spacing: compact ? 12 : 16,
      children: [
        StatCard(
            label: 'Total learning hours',
            value: fmtHours(s.totalMinutes),
            footer: '${s.sessions.length} sessions logged',
            icon: Icons.schedule_rounded,
            colors: Grads.indigo,
            onTap: () => context.go('/analytics')),
        StatCard(
            label: 'This week',
            value: '${fmtHours(weekMin)} h',
            footer: 'Target ${fmtHours(settings.dailyTargetMinutes * 7)} h',
            icon: Icons.date_range_rounded,
            colors: Grads.emerald,
            onTap: () => context.go('/review')),
        StatCard(
            label: 'Today\'s study time',
            value: fmtMinutes(todayMin),
            footer: 'Goal ${fmtMinutes(settings.dailyTargetMinutes)}',
            icon: Icons.today_rounded,
            colors: Grads.orange,
            onTap: () => context.go('/sessions')),
        StatCard(
            label: 'Active goals',
            value: '$active',
            footer: '${s.goals.length} total goals',
            icon: Icons.flag_rounded,
            colors: Grads.violet,
            onTap: () => context.go('/goals')),
        StatCard(
            label: 'Completed goals',
            value: '$completed',
            footer: completed == 0 ? 'None yet' : 'Nicely done',
            icon: Icons.verified_rounded,
            colors: Grads.teal,
            onTap: () => context.go('/goals')),
        StatCard(
            label: 'Current streak',
            value: '${streak.current} d',
            footer: streak.frozenDays.contains(dateKey(s.today.subtract(const Duration(days: 1)))) ? 'Freeze saved it' : 'Longest ${streak.longest} d',
            icon: Icons.local_fire_department_rounded,
            colors: Grads.red,
            onTap: () => context.go('/analytics')),
        StatCard(
            label: 'Active days',
            value: '${streak.activeDays.length}',
            footer: 'Days with learning',
            icon: Icons.event_available_rounded,
            colors: Grads.amber,
            onTap: () => context.go('/analytics')),
        StatCard(
            label: 'Problems solved',
            value: '$solved',
            footer: '${s.problems.length} attempted',
            icon: Icons.code_rounded,
            colors: Grads.sky,
            onTap: () => context.go('/coding')),
        StatCard(
            label: 'Cards due',
            value: '${s.cardsDue}',
            footer: s.cards.isEmpty ? 'No flashcards yet' : '${s.cards.length} cards total',
            icon: Icons.style_rounded,
            colors: Grads.indigo,
            onTap: () => context.go('/flashcards')),
        StatCard(
            label: 'Milestones done',
            value: '$msDone',
            footer: '${s.milestones.length - msDone} open',
            icon: Icons.emoji_events_rounded,
            colors: Grads.rose,
            onTap: () => context.go('/milestones')),
        StatCard(
            label: 'Goals at risk',
            value: '$atRisk',
            footer: atRisk == 0 ? 'All clear' : 'Needs attention',
            icon: Icons.warning_amber_rounded,
            colors: Grads.slate,
            onTap: () => context.go('/analysis')),
      ],
    );

    final dailyGoal = DailyGoalCard(s, settings.dailyTargetMinutes);
    final levelCard = xp == null ? null : LevelCard(xp, streak);
    final todayPlan = TodayPlanCard(s);
    final nextAction = NextActionCard(s, analyses);
    final weekly = SectionCard(
        title: 'Weekly study activity',
        trailing: TextButton(onPressed: () => context.go('/analytics'), child: const Text('Details')),
        child: WeeklyActivityChart(s, weekStart));
    final dist = SectionCard(
        title: 'Subject distribution',
        trailing: TextButton(onPressed: () => context.go('/subjects'), child: const Text('Subjects')),
        child: SubjectPieChart(s));
    final goalProgress = SectionCard(
        title: 'Goal progress',
        trailing: TextButton(onPressed: () => context.go('/goals'), child: const Text('All goals')),
        child: GoalProgressList(analyses));
    final recent = SectionCard(title: 'Recent activity', child: RecentActivityList(s));
    final heat = SectionCard(
        title: 'Streak calendar', child: StreakHeatmap(s, streak.activeDays, compact ? 12 : 20));
    final deadlines = SectionCard(title: 'Upcoming deadlines', child: DeadlinesList(s));
    final quick = SectionCard(title: 'Quick actions', child: QuickActionsBar());

    return PageBody(children: [
      PageHeader(
        title: _greeting(settings.profileName),
        subtitle: DateFormat('EEEE, d MMMM').format(s.now),
      ),
      if (empty) ...[OnboardingCard(), const SizedBox(height: 16)],
      if (compact) ...[
        StartSessionCard(),
        const SizedBox(height: 12),
        if (levelCard != null) ...[levelCard, const SizedBox(height: 12)],
        dailyGoal,
        const SizedBox(height: 12),
        todayPlan,
        const SizedBox(height: 12),
        stats,
        const SizedBox(height: 12),
        nextAction,
        const SizedBox(height: 12),
        deadlines,
        const SizedBox(height: 12),
        goalProgress,
        const SizedBox(height: 12),
        heat,
        const SizedBox(height: 12),
        weekly,
        const SizedBox(height: 12),
        dist,
        const SizedBox(height: 12),
        recent,
        const SizedBox(height: 12),
        quick,
        for (final t in tips.take(2)) ...[const SizedBox(height: 12), TipCard(t)],
      ] else ...[
        stats,
        const SizedBox(height: 16),
        AdaptiveGrid(minTile: 420, maxColumns: 3, children: [?levelCard, dailyGoal, nextAction, todayPlan, quick]),
        const SizedBox(height: 16),
        if (tips.isNotEmpty) ...[
          SectionCard(title: 'Smart coach', child: Column(children: [for (final t in tips.take(3)) TipCard(t)])),
          const SizedBox(height: 16),
        ],
        AdaptiveGrid(minTile: 460, maxColumns: 2, children: [weekly, dist, goalProgress, deadlines, heat, recent]),
      ],
    ]);
  }

  String _greeting(String name) {
    final h = s.now.hour;
    final g = h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
    return name.isEmpty ? g : '$g, $name';
  }
}
