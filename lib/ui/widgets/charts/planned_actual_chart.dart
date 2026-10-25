import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/colors/app_colors.dart';
import '../../../core/services/snapshot.dart';
import '../no_data.dart';
import '../pill.dart';

class PlannedActualChart extends StatelessWidget {
  const PlannedActualChart(this.s, {super.key});
  final Snapshot s;
  @override
  Widget build(BuildContext context) {
    final thisWeek = s.today.subtract(Duration(days: s.today.weekday - 1));
    final weeks = [for (var i = 7; i >= 0; i--) thisWeek.subtract(Duration(days: 7 * i))];
    final planned = [
      for (final w in weeks)
        s.activities.where((a) => !a.start.isBefore(w) && a.start.isBefore(w.add(const Duration(days: 7)))).fold<int>(0, (x, a) => x + a.plannedMinutes) / 60.0
    ];
    final actual = [for (final w in weeks) s.minutesBetween(w, w.add(const Duration(days: 7))) / 60.0];
    if (planned.every((e) => e == 0) && actual.every((e) => e == 0)) return const NoData();
    final maxY = ([...planned, ...actual].fold<double>(0, (a, b) => a > b ? a : b) * 1.2).clamp(1.0, 100.0);
    return Column(children: [
      SizedBox(
        height: 190,
        child: BarChart(BarChartData(
          maxY: maxY,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(drawVerticalLine: false, horizontalInterval: maxY / 4),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: maxY / 4, getTitlesWidget: (v, m) => Text('${v.toStringAsFixed(0)}h', style: const TextStyle(fontSize: 10, color: Palette.muted)))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Padding(padding: const EdgeInsets.only(top: 6), child: Text(DateFormat('d/M').format(weeks[v.toInt()]), style: const TextStyle(fontSize: 10, color: Palette.muted))))),
          ),
          barGroups: [
            for (var i = 0; i < weeks.length; i++)
              BarChartGroupData(x: i, barsSpace: 2, barRods: [
                BarChartRodData(toY: planned[i], width: 8, color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(3)),
                BarChartRodData(toY: actual[i], width: 8, color: Palette.brand, borderRadius: BorderRadius.circular(3)),
              ]),
          ],
        )),
      ),
      const SizedBox(height: 8),
      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Pill('Planned', color: Color(0xFF94A3B8)),
        SizedBox(width: 8),
        Pill('Actual', color: Palette.brand),
      ]),
    ]);
  }
}
