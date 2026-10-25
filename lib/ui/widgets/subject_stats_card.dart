import 'package:flutter/material.dart';
import '../../core/colors/app_colors.dart';
import '../../core/models/coding_problem.dart';
import '../../core/models/enums.dart';
import '../../core/services/snapshot.dart';
import '../../core/utils/pickers.dart';

class SubjectStatsCard extends StatelessWidget {
  const SubjectStatsCard(this.s, {super.key});
  final Snapshot s;
  @override
  Widget build(BuildContext context) {
    final by = <String, List<CodingProblem>>{};
    for (final p in s.problems) {
      final topic = s.topics.where((t) => t.id == p.topicId).map((t) => t.name).firstOrNull;
      final key = topic ?? subjectNameOf(s, p.subjectId) ?? 'Unassigned';
      by.putIfAbsent(key, () => []).add(p);
    }
    final entries = by.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
    return Column(children: [
      for (final e in entries.take(6))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Expanded(child: Text(e.key, overflow: TextOverflow.ellipsis)),
            Text('${e.value.where((p) => p.result == ProblemResult.solved).length}/${e.value.length} solved', style: const TextStyle(color: Palette.muted)),
          ]),
        ),
    ]);
  }
}
