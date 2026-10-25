import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors/app_colors.dart';
import '../../core/models/subject.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/repository.dart';
import '../../core/services/snapshot.dart';
import '../../core/utils/format.dart';
import '../flows/subject_flow.dart';
import 'confirmation_dialog.dart';
import 'progress_bar.dart';

class SubjectCard extends ConsumerWidget {
  const SubjectCard(this.sub, this.s, {super.key});
  final Subject sub;
  final Snapshot s;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    final topics = s.topics.where((t) => t.subjectId == sub.id).toList();
    final done = topics.where((t) => t.status == 'done').length;
    final mins = s.sessions.where((x) => x.subjectId == sub.id).fold<int>(0, (a, x) => a + x.activeSeconds ~/ 60);
    final color = Color(sub.color);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
          child: Icon(iconFor(sub.icon), color: color),
        ),
        title: Text(sub.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${sub.category} · ${topics.isEmpty ? 'No topics' : '$done/${topics.length} topics'} · ${fmtMinutes(mins)} studied'
                '${sub.targetHours > 0 ? ' of ${sub.targetHours.toStringAsFixed(0)}h target' : ''}'),
            const SizedBox(height: 6),
            ProgressBar(topics.isEmpty ? 0 : done / topics.length, color: color, height: 6),
          ]),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.tonalIcon(
                  onPressed: () => editTopic(context, ref, s, sub.id),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add topic')),
              OutlinedButton.icon(
                  onPressed: () => editSubject(context, ref, subject: sub),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit')),
              OutlinedButton.icon(
                  onPressed: () async {
                    sub.archived = !sub.archived;
                    await repo.saveSubject(sub);
                  },
                  icon: Icon(sub.archived ? Icons.unarchive_outlined : Icons.archive_outlined, size: 18),
                  label: Text(sub.archived ? 'Restore' : 'Archive')),
              OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Palette.danger),
                  onPressed: () async {
                    final links = await repo.subjectLinkCounts(sub.id);
                    if (!context.mounted) return;
                    final ok = await confirm(
                        context,
                        'Delete "${sub.name}"?',
                        'Its ${topics.length} topics will be deleted. $links linked sessions, goals, notes and '
                            'problems are kept and will simply show no subject. Archive instead if you may want it back.');
                    if (ok) await repo.deleteSubject(sub.id);
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete')),
            ]),
          ),
          const SizedBox(height: 8),
          if (topics.isEmpty)
            const Padding(padding: EdgeInsets.all(8), child: Text('No topics yet.', style: TextStyle(color: Palette.muted))),
          for (final t in topics)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Checkbox(
                  value: t.status == 'done',
                  onChanged: (v) {
                    t.status = v == true ? 'done' : 'todo';
                    repo.saveTopic(t);
                  }),
              title: Text(t.name, style: TextStyle(decoration: t.status == 'done' ? TextDecoration.lineThrough : null)),
              subtitle: Text('${fmtMinutes(t.estimatedMinutes)} · ${t.difficulty}'
                  '${t.revisionStatus == 'due' ? ' · revision due' : ''}'
                  '${t.prerequisiteId != null ? ' · needs ${s.topics.where((x) => x.id == t.prerequisiteId).map((x) => x.name).firstOrNull ?? '?'}' : ''}'),
              trailing: PopupMenuButton<String>(
                tooltip: 'Topic actions',
                onSelected: (v) async {
                  if (v == 'edit') {
                    await editTopic(context, ref, s, sub.id, topic: t);
                  } else {
                    await repo.deleteTopic(t.id);
                  }
                },
                itemBuilder: (c) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
