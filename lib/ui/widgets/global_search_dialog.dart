import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/colors/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/repository.dart';

Future<void> showGlobalSearch(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (c) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
        child: const _SearchPanel(),
      ),
    ),
  );
}

class _SearchPanel extends ConsumerStatefulWidget {
  const _SearchPanel();
  @override
  ConsumerState<_SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<_SearchPanel> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(snapshotProvider).value;
    final results = <(IconData, String, String, String)>[];
    if (snap != null && q.trim().isNotEmpty) {
      final k = q.toLowerCase();
      for (final g in snap.goals) {
        if (g.title.toLowerCase().contains(k)) results.add((Icons.flag_outlined, g.title, 'Goal', '/goals'));
      }
      for (final s in snap.subjects) {
        if (s.name.toLowerCase().contains(k)) {
          results.add((Icons.library_books_outlined, s.name, 'Subject', '/subjects'));
        }
      }
      for (final p in snap.problems) {
        if (p.title.toLowerCase().contains(k)) results.add((Icons.code, p.title, 'Coding problem', '/coding'));
      }
      for (final t in snap.topics) {
        if (t.name.toLowerCase().contains(k)) results.add((Icons.topic_outlined, t.name, 'Topic', '/subjects'));
      }
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Search goals, subjects, topics, problems…',
              prefixIcon: Icon(Icons.search_rounded)),
          onChanged: (v) => setState(() => q = v),
        ),
      ),
      Flexible(
        child: FutureBuilder(
          future: q.trim().isEmpty ? null : ref.read(repoProvider).notes(query: q),
          builder: (c, noteSnap) {
            final notes = noteSnap.data ?? const [];
            final all = [
              ...results,
              for (final n in notes) (Icons.sticky_note_2_outlined, n.title, 'Note', '/notes'),
            ];
            if (q.trim().isEmpty) {
              return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Type to search everything stored on this device.',
                      style: TextStyle(color: Palette.muted)));
            }
            if (all.isEmpty) {
              return const Padding(padding: EdgeInsets.all(24), child: Text('No matches.'));
            }
            return ListView(shrinkWrap: true, children: [
              for (final r in all.take(40))
                ListTile(
                  leading: Icon(r.$1, color: Theme.of(context).colorScheme.primary),
                  title: Text(r.$2, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(r.$3),
                  onTap: () {
                    Navigator.pop(context);
                    context.go(r.$4);
                  },
                ),
            ]);
          },
        ),
      ),
    ]);
  }
}
