import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/colors/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../no_data.dart';

class DailyHoursChart extends StatelessWidget {
  const DailyHoursChart(this.byDay, this.start, this.span, {super.key});
  final Map<String, int> byDay;
  final DateTime start;
  final int span;
  @override
  Widget build(BuildContext context) {
    if (byDay.isEmpty) return const NoData();
    final n = span > 60 ? 60 : span;
    final first = dayOnly(start).add(Duration(days: span - n));
    final vals = [for (var i = 0; i < n; i++) (byDay[dateKey(first.add(Duration(days: i)))] ?? 0) / 60.0];
    final maxY = (vals.fold<double>(0, (a, b) => a > b ? a : b) * 1.2).clamp(1.0, 24.0);
    return SizedBox(
      height: 200,
      child: BarChart(BarChartData(
        maxY: maxY,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(drawVerticalLine: false, horizontalInterval: maxY / 4),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: maxY / 4, getTitlesWidget: (v, m) => Text('${v.toStringAsFixed(1)}h', style: const TextStyle(fontSize: 10, color: Palette.muted)))),
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (v, m) => v.toInt() % (n / 6).ceil() != 0
                      ? const SizedBox.shrink()
                      : Padding(padding: const EdgeInsets.only(top: 6), child: Text(DateFormat('d/M').format(first.add(Duration(days: v.toInt()))), style: const TextStyle(fontSize: 10, color: Palette.muted))))),
        ),
        barGroups: [for (var i = 0; i < n; i++) BarChartGroupData(x: i, barRods: [BarChartRodData(toY: vals[i], width: n > 30 ? 4 : 10, color: Palette.brand, borderRadius: BorderRadius.circular(3))])],
      )),
    );
  }
}
