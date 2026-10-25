import 'dart:math' as math;
import '../models/activity.dart';
import '../models/enums.dart';
import '../models/goal.dart';
import 'goal_analyzer.dart';
import 'snapshot.dart';
import '../utils/date_format.dart';

class SchedulePlan {
  SchedulePlan(this.activities, this.unscheduledMinutes, this.keptCount, this.removedCount);
  final List<Activity> activities;
  final int unscheduledMinutes;
  final int keptCount;
  final int removedCount;
  bool get fits => unscheduledMinutes == 0;
}

class ScheduleGenerator {
  /// Builds a proposed plan. It never exceeds the user's availability — if the
  /// work doesn't fit, [SchedulePlan.unscheduledMinutes] reports the gap and
  /// the caller must surface it instead of silently over-scheduling.
  static SchedulePlan generate(Goal g, Snapshot s, {int chunkMinutes = 45}) {
    final analysis = GoalAnalyzer.analyze(g, s);
    final remaining = analysis.remainingMinutes ?? 0;
    final now = s.now;
    final end = g.deadline ?? s.today.add(const Duration(days: 28));
    final existing = s.activities.where((a) => a.goalId == g.id).toList();
    final removable = existing
        .where((a) => a.generated && !a.done && a.status != 'skipped' && a.plannedStart >= now.millisecondsSinceEpoch)
        .toList();
    final keptIds = removable.map((a) => a.id).toSet();

    // Items to schedule: topics → milestones → generic chunks.
    final items = <(String, ActivityKind, int, String)>[];
    final ts = s.topics.where((t) => t.goalId == g.id && t.status != 'done').toList();
    final ms = s.milestones.where((m) => m.goalId == g.id && !m.done).toList();
    for (final t in ts) {
      var left = t.estimatedMinutes;
      var part = 1;
      final parts = (left / chunkMinutes).ceil();
      while (left > 0) {
        final c = math.min(left, chunkMinutes + 15);
        items.add((parts > 1 ? 'Learn: ${t.name} ($part/$parts)' : 'Learn: ${t.name}', ActivityKind.study, c,
            'Can explain and apply ${t.name}'));
        left -= c;
        part++;
      }
      items.add(('Practice: ${t.name}', ActivityKind.practice, 30, 'Solve 3 exercises on ${t.name}'));
    }
    for (final m in ms) {
      if (m.estimatedMinutes > 0 && ts.isEmpty) {
        var left = m.estimatedMinutes;
        while (left > 0) {
          final c = math.min(left, chunkMinutes + 15);
          items.add(('Work on: ${m.title}', ActivityKind.study, c, m.criteria));
          left -= c;
        }
      }
      items.add(('Assess: ${m.title}', ActivityKind.assessment, 20,
          m.criteria.isEmpty ? 'Milestone criteria met' : m.criteria));
    }
    if (items.isEmpty && remaining > 0) {
      var left = remaining;
      var i = 1;
      while (left > 0) {
        final c = math.min(left, chunkMinutes);
        items.add(('${g.title} — focus block $i', ActivityKind.study, c, 'Finish the planned block'));
        left -= c;
        i++;
      }
    }
    // Revision every 5 items
    final withRev = <(String, ActivityKind, int, String)>[];
    for (var i = 0; i < items.length; i++) {
      withRev.add(items[i]);
      if ((i + 1) % 5 == 0) {
        withRev.add(('Revise recent topics', ActivityKind.revision, 20, 'Recall key points without notes'));
      }
    }

    // Free minutes per day = availability*0.9 − other already-scheduled minutes
    final used = <String, int>{};
    for (final a in s.activities) {
      if (keptIds.contains(a.id)) continue;
      if (a.status == 'skipped') continue;
      final k = dateKey(a.start);
      used[k] = (used[k] ?? 0) + a.plannedMinutes;
    }
    final out = <Activity>[];
    var day = s.today;
    var idx = 0;
    var unscheduled = 0;
    int? carry;
    while (idx < withRev.length && !day.isAfter(end)) {
      final avail = ((s.availability[day.weekday] ?? 0) * 0.9).floor();
      var free = avail - (used[dateKey(day)] ?? 0);
      var cursor = DateTime(day.year, day.month, day.day, s.studyHour)
          .add(Duration(minutes: used[dateKey(day)] ?? 0));
      while (idx < withRev.length) {
        final it = withRev[idx];
        final need = carry ?? it.$3;
        if (need > free) break;
        if (cursor.isBefore(now)) {
          cursor = now.add(const Duration(minutes: 5));
        }
        out.add(Activity(
          title: it.$1,
          subjectId: g.subjectId,
          goalId: g.id,
          kind: it.$2,
          plannedStart: cursor.millisecondsSinceEpoch,
          plannedEnd: cursor.add(Duration(minutes: need)).millisecondsSinceEpoch,
          plannedMinutes: need,
          priority: g.priority,
          criteria: it.$4,
          generated: true,
        ));
        cursor = cursor.add(Duration(minutes: need + 5));
        free -= need;
        carry = null;
        idx++;
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
    for (var i = idx; i < withRev.length; i++) {
      unscheduled += withRev[i].$3;
    }
    final kept = existing.length - removable.length;
    return SchedulePlan(out, unscheduled, kept, removable.length);
  }
}
