import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/colors/app_colors.dart';
import '../../../core/models/subject.dart';
import '../../../core/services/snapshot.dart';

class SubjectPieChart extends StatelessWidget {
  const SubjectPieChart(this.s, {super.key});
  final Snapshot s;
  @override
  Widget build(BuildContext context) {
    final by = <String?, int>{};
    for (final x in s.sessions) {
      by[x.subjectId] = (by[x.subjectId] ?? 0) + x.activeSeconds ~/ 60;
    }
    for (final p in s.problems.where((p) => p.sessionId == null)) {
      by[p.subjectId] = (by[p.subjectId] ?? 0) + p.minutes;
    }
    by.removeWhere((k, v) => v <= 0);
    if (by.isEmpty) {
      return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('Log a session to see where your time goes.', style: TextStyle(color: Palette.muted)));
    }
    final entries = by.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    Subject? sub(String? id) => s.subjects.where((x) => x.id == id).firstOrNull;
    final total = entries.fold<int>(0, (a, b) => a + b.value);
    return LayoutBuilder(builder: (context, c) {
      final pie = SizedBox(
        height: 170,
        width: 170,
        child: PieChart(PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 42,
          sections: [
            for (final e in entries)
              PieChartSectionData(
                  value: e.value.toDouble(),
                  title: '',
                  radius: 34,
                  color: Color(sub(e.key)?.color ?? 0xFF94A3B8)),
          ],
        )),
      );
      final legend = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final e in entries.take(6))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: Color(sub(e.key)?.color ?? 0xFF94A3B8), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(sub(e.key)?.name ?? 'No subject', overflow: TextOverflow.ellipsis)),
              Text('${(e.value * 100 / total).round()}%', style: const TextStyle(color: Palette.muted)),
            ]),
          ),
      ]);
      if (c.maxWidth < 380) {
        return Column(children: [pie, const SizedBox(height: 12), legend]);
      }
      return Row(children: [pie, const SizedBox(width: 20), Expanded(child: legend)]);
    });
  }
}
