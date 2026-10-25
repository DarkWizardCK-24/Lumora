import 'dart:math' as math;
import '../models/enums.dart';
import '../models/goal.dart';
import 'snapshot.dart';
import '../utils/date_format.dart';
import '../utils/format.dart';

enum DeadlineStatus {
  onTrack('On Track'),
  adjustments('Achievable with Adjustments'),
  atRisk('At Risk'),
  unlikely('Unlikely Within Deadline'),
  completed('Completed'),
  passed('Deadline Passed'),
  noDeadline('No Deadline'),
  needsEstimate('Needs Estimate');

  const DeadlineStatus(this.label);
  final String label;
}

enum Confidence { low, medium, high }

class GoalAnalysis {
  GoalAnalysis({
    required this.goal,
    required this.status,
    required this.confidence,
    required this.estimateSource,
    required this.loggedMinutes,
    this.remainingMinutes,
    this.optimistic,
    this.realistic,
    this.conservative,
    this.daysLeft,
    this.studyDaysLeft = 0,
    this.capacityMinutes = 0,
    this.requiredDaily,
    this.requiredWeekly,
    this.gapMinutes = 0,
    this.progress = 0,
    this.risks = const [],
    this.alternatives = const [],
    this.nextAction = '',
    this.calibration = 1,
  });
  final Goal goal;
  final DeadlineStatus status;
  final Confidence confidence;
  final String estimateSource;
  final int loggedMinutes;
  final int? remainingMinutes;
  final DateTime? optimistic, realistic, conservative;
  final int? daysLeft;
  final int studyDaysLeft, capacityMinutes;
  final int? requiredDaily, requiredWeekly;
  final int gapMinutes;
  final double progress; // 0..1
  final List<String> risks, alternatives;
  final String nextAction;
  final double calibration;
}

class GoalAnalyzer {
  static const _prioWeight = {1: 1.0, 2: 2.0, 3: 3.0};

  /// Personal calibration: how much longer/shorter goals took vs. estimate.
  /// Shrunk toward 1.0 with few samples so one outlier can't swing forecasts.
  static double calibration(Snapshot s) {
    final ratios = <double>[];
    for (final g in s.goals) {
      if (g.status == GoalStatus.completed && (g.estimatedMinutes ?? 0) > 0) {
        final actual = s.goalMinutes(g.id);
        if (actual > 0) ratios.add(actual / g.estimatedMinutes!);
      }
    }
    if (ratios.isEmpty) return 1;
    final avg = ratios.reduce((a, b) => a + b) / ratios.length;
    final w = ratios.length / (ratios.length + 3);
    return (1 + (avg - 1) * w).clamp(0.8, 1.6);
  }

  static double progressOf(Goal g, Snapshot s) {
    if (g.status == GoalStatus.completed) return 1;
    if (g.manualProgress != null) return g.manualProgress! / 100; // never overridden
    final ms = s.milestones.where((m) => m.goalId == g.id).toList();
    final ts = s.topics.where((t) => t.goalId == g.id).toList();
    final total = ms.length + ts.length;
    if (total > 0) {
      final done = ms.where((m) => m.done).length + ts.where((t) => t.status == 'done').length;
      return done / total;
    }
    return 0; // time alone is not evidence of mastery
  }

  static GoalAnalysis analyze(Goal g, Snapshot s) {
    final logged = s.goalMinutes(g.id);
    final progress = progressOf(g, s);
    if (g.status == GoalStatus.completed) {
      return GoalAnalysis(
          goal: g,
          status: DeadlineStatus.completed,
          confidence: Confidence.high,
          estimateSource: 'Completed',
          loggedMinutes: logged,
          progress: 1,
          nextAction: 'Review what you learned and set the next goal.');
    }

    // --- remaining effort: use the most trustworthy source available
    int? remaining;
    var source = 'No estimate yet';
    var conf = Confidence.low;
    final ms = s.milestones.where((m) => m.goalId == g.id && !m.done).toList();
    final ts = s.topics.where((t) => t.goalId == g.id && t.status != 'done').toList();
    final cal = calibration(s);
    if (g.remainingMinutes != null) {
      remaining = g.remainingMinutes;
      source = 'Your remaining-effort estimate';
      conf = Confidence.medium;
    } else if (ms.fold<int>(0, (a, m) => a + m.estimatedMinutes) +
            ts.fold<int>(0, (a, t) => a + t.estimatedMinutes) >
        0) {
      remaining = ms.fold<int>(0, (a, m) => a + m.estimatedMinutes) +
          ts.fold<int>(0, (a, t) => a + t.estimatedMinutes);
      source = 'Open milestones & topics';
      conf = Confidence.medium;
    } else if ((g.estimatedMinutes ?? 0) > 0) {
      remaining = math.max(0, g.estimatedMinutes! - logged);
      source = 'Total estimate minus logged time';
      conf = Confidence.medium;
    } else {
      final similar = s.goals.where((o) =>
          o.id != g.id &&
          o.status == GoalStatus.completed &&
          o.subjectId != null &&
          o.subjectId == g.subjectId);
      final actuals = similar.map((o) => s.goalMinutes(o.id)).where((m) => m > 0).toList();
      if (actuals.isNotEmpty) {
        remaining = (actuals.reduce((a, b) => a + b) / actuals.length).round();
        source = 'Similar completed goals';
      }
    }

    final dl = g.deadline;
    final daysLeft = dl?.difference(s.today).inDays;
    final risks = <String>[];
    final alts = <String>[];

    if (remaining == null) {
      return GoalAnalysis(
          goal: g,
          status: DeadlineStatus.needsEstimate,
          confidence: Confidence.low,
          estimateSource: source,
          loggedMinutes: logged,
          daysLeft: daysLeft,
          progress: progress,
          risks: ['No effort estimate, milestones or topics exist, so a forecast would be a guess.'],
          nextAction: 'Add an effort estimate, topics or milestones to unlock forecasting.');
    }
    if (source != 'Your remaining-effort estimate') {
      remaining = (remaining * cal).round();
    }
    if (g.remainingMinutes == null &&
        g.manualProgress != null &&
        source == 'Total estimate minus logged time') {
      // manual progress is authoritative for how much is left
      remaining = ((g.estimatedMinutes! * (1 - progress)) * cal).round();
    }

    // --- capacity: user availability, shared with other deadline goals by priority
    final others = s.goals.where((o) =>
        o.id != g.id &&
        o.deadline != null &&
        (o.status == GoalStatus.inProgress || o.status == GoalStatus.notStarted) &&
        !o.archived);
    final myW = _prioWeight[g.priority] ?? 2;
    final share = myW / (myW + others.fold<double>(0, (a, o) => a + (_prioWeight[o.priority] ?? 2)));
    final end = dl ?? s.today.add(const Duration(days: 90));
    var capacity = 0.0;
    var studyDays = 0;
    final startDay = s.today;
    for (var d = startDay; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
      final a = s.availability[d.weekday] ?? 0;
      if (a > 0) {
        studyDays++;
        capacity += a * 0.9 * share; // 10% buffer; share for competing goals
      }
    }
    final cap = capacity.round();
    final avgDaily = studyDays == 0 ? 0.0 : capacity / studyDays;

    // --- pace: blend planned capacity with demonstrated recent speed
    final recent = s.goalMinutes(g.id, since: s.today.subtract(const Duration(days: 28)));
    final activeRecentDays = s.sessions
        .where((x) =>
            x.goalId == g.id && fromMs(x.startedAt).isAfter(s.today.subtract(const Duration(days: 28))))
        .map((x) => dateKey(fromMs(x.startedAt)))
        .toSet()
        .length;
    final plannedPerCalendarDay = capacity / math.max(1, (end.difference(startDay).inDays + 1));
    var pace = plannedPerCalendarDay;
    if (activeRecentDays >= 3) {
      pace = 0.5 * plannedPerCalendarDay + 0.5 * (recent / 28);
      if (conf == Confidence.medium) conf = Confidence.high;
    }
    pace = math.max(pace, 1);

    DateTime finish(double mins, double paceF) =>
        s.today.add(Duration(days: (mins / (paceF * 1.0)).ceil()));
    final rem = remaining.toDouble();
    final optimistic = finish(rem * 0.85, pace * 1.15);
    final realistic = finish(rem * 1.1, pace);
    final conservative = finish(rem * 1.3, pace * 0.8);

    int? reqDaily, reqWeekly;
    var gap = 0;
    var status = DeadlineStatus.noDeadline;
    if (dl != null) {
      if (daysLeft! < 0) {
        status = DeadlineStatus.passed;
        risks.add('The target date passed ${-daysLeft} day(s) ago with work remaining.');
      } else {
        reqDaily = studyDays == 0 ? null : (remaining / studyDays).ceil();
        reqWeekly = (remaining / math.max(1, (daysLeft + 1) / 7)).ceil();
        gap = math.max(0, (remaining * 1.1).round() - cap);
        final ratio = cap == 0 ? double.infinity : remaining * 1.1 / cap;
        if (ratio <= 0.8 && !realistic.isAfter(dl)) {
          status = DeadlineStatus.onTrack;
        } else if (ratio <= 1.0) {
          status = DeadlineStatus.adjustments;
        } else if (ratio <= 1.25) {
          status = DeadlineStatus.atRisk;
        } else {
          status = DeadlineStatus.unlikely;
        }
        if (realistic.isAfter(dl) && status == DeadlineStatus.onTrack) {
          status = DeadlineStatus.adjustments;
        }
        if (gap > 0) {
          risks.add(
              'About ${humanDuration(remaining)} of work remains but your available capacity is ${humanDuration(cap)}.');
        }
        if (activeRecentDays == 0 && logged == 0) {
          risks.add('No study sessions are logged against this goal yet.');
        } else if (activeRecentDays == 0) {
          risks.add('No recent activity on this goal in the last 4 weeks.');
        }
        if (others.isNotEmpty) {
          risks.add('${others.length} other deadline goal(s) share your study time.');
        }
        if (status != DeadlineStatus.onTrack) {
          alts.addAll([
            'Reduce scope — move optional topics to a later goal.',
            'Extend the deadline to ${shortDate(realistic)} (realistic finish).',
            'Prioritise essential topics first.',
            if (gap > 0) 'Add about ${humanDuration(gap)} of study time within your own limits.',
            if (others.isNotEmpty) 'Pause or reschedule a competing goal.',
          ]);
        }
      }
    }
    if (conf == Confidence.low && source == 'Similar completed goals') {
      risks.add('Estimate is inferred from similar goals — treat it as approximate.');
    }
    if (cal > 1.15) {
      risks.add('Your past goals took ~${((cal - 1) * 100).round()}% longer than estimated; forecasts include that.');
    }

    String next;
    final nextTopic = ts.isEmpty ? null : ts.first;
    final nextMs = ms.isEmpty ? null : ms.first;
    if (nextTopic != null) {
      next = 'Study "${nextTopic.name}" for ${math.min(nextTopic.estimatedMinutes, math.max(25, avgDaily.round()))} min.';
    } else if (nextMs != null) {
      next = 'Work toward milestone "${nextMs.title}".';
    } else {
      next = 'Do a ${math.max(25, math.min(60, avgDaily.round()))}-minute session on this goal today.';
    }

    return GoalAnalysis(
      goal: g,
      status: status,
      confidence: conf,
      estimateSource: source,
      loggedMinutes: logged,
      remainingMinutes: remaining,
      optimistic: optimistic,
      realistic: realistic,
      conservative: conservative,
      daysLeft: daysLeft,
      studyDaysLeft: studyDays,
      capacityMinutes: cap,
      requiredDaily: reqDaily,
      requiredWeekly: reqWeekly,
      gapMinutes: gap,
      progress: progress,
      risks: risks,
      alternatives: alts,
      nextAction: next,
      calibration: cal,
    );
  }
}
