import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/colors/app_colors.dart';
import '../../../core/models/enums.dart';
import '../../../core/services/snapshot.dart';
import '../../../core/utils/date_format.dart';
import '../no_data.dart';

class SolvedTrendChart extends StatelessWidget {
  const SolvedTrendChart(this.s, {super.key});
  final Snapshot s;
  @override
  Widget build(BuildContext context) {
    final thisWeek = s.today.subtract(Duration(days: s.today.weekday - 1));
    final weeks = [for (var i = 9; i >= 0; i--) thisWeek.subtract(Duration(days: 7 * i))];
    final vals = [
      for (final w in weeks)
        s.problems.where((p) => p.result == ProblemResult.solved && !fromMs(p.attemptedAt).isBefore(w) && fromMs(p.attemptedAt).isBefore(w.add(const Duration(days: 7)))).length.toDouble()
    ];
    if (vals.every((v) => v == 0)) return const NoData();
    final maxY = vals.fold<double>(1, (a, b) => a > b ? a : b) + 1;
    return SizedBox(
      height: 180,
      child: LineChart(LineChartData(
        minY: 0,
        maxY: maxY,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(drawVerticalLine: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, interval: (maxY / 4).ceilToDouble(), getTitlesWidget: (v, m) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: Palette.muted)))),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 2, getTitlesWidget: (v, m) => Padding(padding: const EdgeInsets.only(top: 6), child: Text(DateFormat('d/M').format(weeks[v.toInt()]), style: const TextStyle(fontSize: 10, color: Palette.muted))))),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < vals.length; i++) FlSpot(i.toDouble(), vals[i])],
            isCurved: true,
            color: Palette.success,
            barWidth: 3,
            belowBarData: BarAreaData(show: true, color: Palette.success.withValues(alpha: 0.12)),
          ),
        ],
      )),
    );
  }
}
