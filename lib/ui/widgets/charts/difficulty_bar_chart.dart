import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/colors/app_colors.dart';
import '../../../core/models/coding_problem.dart';
import '../../../core/models/enums.dart';

class DifficultyBarChart extends StatelessWidget {
  const DifficultyBarChart(this.problems, {super.key});
  final List<CodingProblem> problems;
  @override
  Widget build(BuildContext context) {
    int c(String d, {bool solved = false}) =>
        problems.where((p) => p.difficulty == d && (!solved || p.result == ProblemResult.solved)).length;
    final maxY = [for (final d in problemDifficulties) c(d)].fold<int>(1, (a, b) => a > b ? a : b) + 1.0;
    return SizedBox(
      height: 170,
      child: BarChart(BarChartData(
        maxY: maxY,
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, interval: 1, getTitlesWidget: (v, m) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: Palette.muted)))),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Padding(padding: const EdgeInsets.only(top: 6), child: Text(problemDifficulties[v.toInt()], style: const TextStyle(fontSize: 11, color: Palette.muted))))),
        ),
        barGroups: [
          for (var i = 0; i < 3; i++)
            BarChartGroupData(x: i, barsSpace: 4, barRods: [
              BarChartRodData(toY: c(problemDifficulties[i]).toDouble(), width: 16, color: const Color(0xFF94A3B8), borderRadius: BorderRadius.circular(4)),
              BarChartRodData(toY: c(problemDifficulties[i], solved: true).toDouble(), width: 16, color: Palette.success, borderRadius: BorderRadius.circular(4)),
            ]),
        ],
      )),
    );
  }
}
