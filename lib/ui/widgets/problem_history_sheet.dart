import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/colors/app_colors.dart';
import '../../core/models/coding_problem.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/format.dart';
import 'code_view.dart';
import 'empty_state.dart';
import 'pill.dart';

String _secs(int s) => s < 60 ? '${s}s' : '${s ~/ 60}m ${(s % 60).toString().padLeft(2, '0')}s';

/// Solve-time trend, saved code and notes for one problem.
Future<void> showProblemHistory(BuildContext context, CodingProblem p, List<ProblemAttempt> attempts) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Text(p.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            Pill(p.difficulty, color: Palette.muted),
            if (p.pattern.isNotEmpty) Pill(p.pattern, color: Palette.brandBlue, icon: Icons.account_tree_outlined),
            Pill('${attempts.length} timed attempts', color: Palette.muted, icon: Icons.timer_outlined),
          ]),
          const SizedBox(height: 16),
          if (attempts.isEmpty)
            const SizedBox(
                height: 200,
                child: EmptyState(icon: Icons.timer_outlined, title: 'No timed attempts yet', message: 'Use the timer on this problem to see your solve time improve.'))
          else ...[
            _Trend(attempts),
            const SizedBox(height: 16),
            for (final a in attempts.reversed)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(a.solved ? Icons.check_circle_rounded : Icons.cancel_outlined, color: a.solved ? Palette.success : Palette.muted),
                title: Text(_secs(a.seconds), style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: Text(fmtDateTime(fromMs(a.at)), style: const TextStyle(color: Palette.muted, fontSize: 12.5)),
              ),
          ],
          if (p.snippet.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Saved solution', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            CodeView(p.snippet, language: p.language),
          ],
        ],
      ),
    ),
  );
}

class _Trend extends StatelessWidget {
  const _Trend(this.attempts);
  final List<ProblemAttempt> attempts;

  @override
  Widget build(BuildContext context) {
    final first = attempts.first.seconds, last = attempts.last.seconds;
    final solved = attempts.where((a) => a.solved).toList();
    final best = solved.isEmpty ? null : solved.map((a) => a.seconds).reduce((a, b) => a < b ? a : b);
    final change = attempts.length < 2 || first == 0 ? null : ((first - last) / first * 100).round();
    final primary = Theme.of(context).colorScheme.primary;
    final maxY = attempts.map((a) => a.seconds).reduce((a, b) => a > b ? a : b) * 1.2;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        Pill('First ${_secs(first)}', color: Palette.muted),
        Pill('Latest ${_secs(last)}', color: primary),
        if (best != null) Pill('Best ${_secs(best)}', color: Palette.success, icon: Icons.emoji_events_outlined),
        if (change != null)
          Pill(change >= 0 ? '$change% faster' : '${-change}% slower', color: change >= 0 ? Palette.success : Palette.warning, icon: change >= 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        height: 140,
        child: LineChart(LineChartData(
          minY: 0,
          maxY: maxY <= 0 ? 60 : maxY,
          gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => const FlLine(color: Palette.border, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: const AxisTitles(),
            leftTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (v, m) => v == m.max || v == m.min && v != 0
                        ? const SizedBox.shrink()
                        : Text(_secs(v.round()), style: const TextStyle(fontSize: 10, color: Palette.muted)))),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < attempts.length; i++) FlSpot(i.toDouble(), attempts[i].seconds.toDouble())],
              isCurved: attempts.length > 2,
              barWidth: 3,
              color: primary,
              dotData: FlDotData(
                  getDotPainter: (spot, _, _, i) => FlDotCirclePainter(
                      radius: 4, color: attempts[i].solved ? Palette.success : Palette.muted, strokeWidth: 2, strokeColor: Colors.white)),
              belowBarData: BarAreaData(show: true, color: primary.withValues(alpha: 0.1)),
            ),
          ],
        )),
      ),
    ]);
  }
}
