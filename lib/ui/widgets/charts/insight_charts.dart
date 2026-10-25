import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/colors/app_colors.dart';
import '../../../core/utils/format.dart';

/// Study minutes for each hour of the day, with the best hour highlighted.
class HourOfDayChart extends StatelessWidget {
  const HourOfDayChart({super.key, required this.minutes, this.bestHour, this.use24h = false});
  final List<double> minutes;
  final int? bestHour;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final maxY = (minutes.fold<double>(0, (a, b) => a > b ? a : b) * 1.2).clamp(10.0, 100000.0);
    return SizedBox(
      height: 190,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (_) => const FlLine(color: Palette.border, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
                  '${fmtHourOfDay(g.x, use24h: use24h)}\n${fmtMinutes(r.toY)}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 38,
                    interval: maxY / 4,
                    getTitlesWidget: (v, m) => v == m.max
                        ? const SizedBox.shrink()
                        : Text(fmtMinutes(v), style: const TextStyle(fontSize: 10, color: Palette.muted)))),
            bottomTitles: AxisTitles(
                sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) => v.toInt() % 6 == 0
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(fmtHourOfDay(v.toInt(), use24h: use24h), style: const TextStyle(fontSize: 10, color: Palette.muted)))
                  : const SizedBox.shrink(),
            )),
          ),
          barGroups: [
            for (var h = 0; h < 24; h++)
              BarChartGroupData(x: h, barRods: [
                BarChartRodData(
                  toY: minutes[h],
                  width: 9,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  color: h == bestHour ? primary : primary.withValues(alpha: 0.35),
                ),
              ]),
          ],
        ),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

/// Twelve monthly bars for the year-in-review.
class MonthChart extends StatelessWidget {
  const MonthChart({super.key, required this.minutes, this.highlight});
  final List<int> minutes;
  final int? highlight; // 1..12
  static const _names = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

  @override
  Widget build(BuildContext context) {
    final maxY = (minutes.fold<int>(0, (a, b) => a > b ? a : b) * 1.2).clamp(10.0, 1e9).toDouble();
    return SizedBox(
      height: 150,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
                  fmtMinutes(r.toY), const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, m) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(_names[v.toInt()], style: const TextStyle(fontSize: 11, color: Colors.white70))))),
          ),
          barGroups: [
            for (var i = 0; i < 12; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: minutes[i].toDouble(),
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                  color: highlight == i + 1 ? Colors.white : Colors.white.withValues(alpha: 0.4),
                ),
              ]),
          ],
        ),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}
