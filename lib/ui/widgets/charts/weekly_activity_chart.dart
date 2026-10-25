import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/colors/app_colors.dart';
import '../../../core/services/snapshot.dart';

class WeeklyActivityChart extends StatelessWidget {
  const WeeklyActivityChart(this.s, this.weekStart, {super.key});
  final Snapshot s;
  final DateTime weekStart;
  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final vals = [for (final d in days) s.minutesOn(d) / 60.0];
    final maxY = (vals.fold<double>(0, (a, b) => a > b ? a : b) * 1.25).clamp(1.0, 24.0);
    return SizedBox(
      height: 190,
      child: BarChart(BarChartData(
        maxY: maxY,
        gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => const FlLine(color: Palette.border, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: maxY / 4,
                  getTitlesWidget: (v, m) => Text('${v.toStringAsFixed(v < 10 ? 1 : 0)}h',
                      style: const TextStyle(fontSize: 10, color: Palette.muted)))),
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, m) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(DateFormat.E().format(days[v.toInt()]),
                          style: const TextStyle(fontSize: 11, color: Palette.muted))))),
        ),
        barGroups: [
          for (var i = 0; i < 7; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                  toY: vals[i],
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  gradient: const LinearGradient(
                      begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xFF0E7490), Color(0xFF38BDF8)])),
            ])
        ],
      )),
    );
  }
}
