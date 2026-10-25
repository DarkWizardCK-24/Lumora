import 'package:flutter/material.dart';
import '../../../core/colors/app_colors.dart';
import '../../../core/services/snapshot.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/format.dart';

class StreakHeatmap extends StatelessWidget {
  const StreakHeatmap(this.s, this.active, this.cell, {super.key});
  final Snapshot s;
  final Set<String> active;
  final double cell;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 3.0;
      final weeks = ((c.maxWidth + gap) / (cell + gap)).floor().clamp(4, 26);
      final start = s.today.subtract(Duration(days: s.today.weekday - 1 + (weeks - 1) * 7));
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (var w = 0; w < weeks; w++)
              Column(children: [
                for (var d = 0; d < 7; d++)
                  Builder(builder: (_) {
                    final day = DateTime(start.year, start.month, start.day + w * 7 + d);
                    final future = day.isAfter(s.today);
                    final m = future ? 0 : s.minutesOn(day);
                    final q = active.contains(dateKey(day));
                    final level = m == 0 ? 0 : m < 30 ? 1 : m < 60 ? 2 : m < 120 ? 3 : 4;
                    final colors = [
                      const Color(0xFFE7EDF5),
                      const Color(0xFFBAE6FD),
                      const Color(0xFF67C8E8),
                      const Color(0xFF1B9BC0),
                      const Color(0xFF0E7490),
                    ];
                    return Tooltip(
                      message: '${fmtDate(day)} · ${fmtMinutes(m)}${q ? ' ✓' : ''}',
                      child: Container(
                        width: cell,
                        height: cell,
                        margin: const EdgeInsets.all(gap / 2),
                        decoration: BoxDecoration(
                          color: future ? Colors.transparent : colors[level],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
              ]),
          ]),
        ),
        const SizedBox(height: 8),
        const Text('Darker = more study time. Last few months.', style: TextStyle(color: Palette.muted, fontSize: 12)),
      ]);
    });
  }
}
