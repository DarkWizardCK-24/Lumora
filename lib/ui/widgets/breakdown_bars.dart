import 'package:flutter/material.dart';
import '../../core/utils/format.dart';
import 'no_data.dart';
import 'progress_bar.dart';

class BreakdownBars extends StatelessWidget {
  const BreakdownBars(this.rows, {super.key});
  final List<(String, int, int)> rows;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const NoData();
    final max = rows.first.$2;
    return Column(children: [
      for (final r in rows.take(8))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(r.$1, overflow: TextOverflow.ellipsis)),
              Text(fmtMinutes(r.$2), style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            ProgressBar(r.$2 / max, color: Color(r.$3), height: 6),
          ]),
        ),
    ]);
  }
}
