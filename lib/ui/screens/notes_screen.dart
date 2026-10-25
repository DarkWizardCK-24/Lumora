import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors/app_colors.dart';
import '../../core/models/note.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/format.dart';
import '../../core/utils/pickers.dart';
import '../../core/utils/responsive.dart';
import '../widgets/empty_state.dart';
import '../widgets/new_action_scope.dart';
import '../widgets/note_editor.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});
  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String query = '';
  String? subject;
  bool favoritesOnly = false, archived = false;
  Note? editing; // desktop detail pane

  void _new() {
    final n = Note(title: '');
    if (Responsive.isCompact(context)) {
      _openFull(n);
    } else {
      setState(() => editing = n);
    }
  }

  void _openFull(Note n) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Note')),
        body: SafeArea(child: NoteEditor(key: ValueKey(n.id), note: n, onClose: () => Navigator.of(context).pop())),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider(query));
    final snap = ref.watch(snapshotProvider).value;
    final wide = !Responsive.isCompact(context);
    return NewActionScope(
      onNew: _new,
      child: notes.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(e),
        data: (all) {
          var list = all.where((n) => n.archived == archived).toList();
          if (favoritesOnly) list = list.where((n) => n.favorite).toList();
          if (subject != null) list = list.where((n) => n.subjectId == subject).toList();
          final listPane = Column(children: [
            Padding(
              padding: EdgeInsets.fromLTRB(wide ? 20 : 16, 16, wide ? 12 : 16, 8),
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: TextField(
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search titles, text and tags'),
                          onChanged: (v) => setState(() => query = v))),
                  const SizedBox(width: 8),
                  FilledButton.icon(onPressed: _new, icon: const Icon(Icons.add), label: const Text('New')),
                ]),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    FilterChip(label: const Text('Favorites'), selected: favoritesOnly, onSelected: (v) => setState(() => favoritesOnly = v)),
                    const SizedBox(width: 6),
                    FilterChip(label: const Text('Archived'), selected: archived, onSelected: (v) => setState(() => archived = v)),
                    const SizedBox(width: 6),
                    if (snap != null)
                      for (final e in subjectOptions(snap).entries.take(8))
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                              label: Text(e.value),
                              selected: subject == e.key,
                              onSelected: (v) => setState(() => subject = v ? e.key : null)),
                        ),
                  ]),
                ),
              ]),
            ),
            Expanded(
              child: list.isEmpty
                  ? EmptyState(
                      icon: Icons.sticky_note_2_outlined,
                      title: all.isEmpty ? 'No notes yet' : 'No notes found',
                      message: all.isEmpty ? 'Capture what you learn. Notes save automatically.' : 'Try a different search or filter.',
                      action: all.isEmpty ? FilledButton(onPressed: _new, child: const Text('Write a note')) : null)
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(wide ? 20 : 16, 4, wide ? 12 : 16, 96),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (c, i) {
                        final n = list[i];
                        final sel = editing?.id == n.id;
                        return Card(
                          color: sel ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.07) : null,
                          child: ListTile(
                            onTap: () => wide ? setState(() => editing = n) : _openFull(n),
                            title: Row(children: [
                              if (n.favorite) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.star_rounded, size: 18, color: Palette.warning)),
                              Expanded(child: Text(n.title.isEmpty ? 'Untitled' : n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                            ]),
                            subtitle: Text(
                                '${n.body.replaceAll('\n', ' ')}\n${fmtDateTime(fromMs(n.updatedAt))}${n.tags.isEmpty ? '' : ' · ${n.tagList.map((t) => '#$t').join(' ')}'}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
            ),
          ]);
          if (!wide) return listPane;
          return Row(children: [
            SizedBox(width: 400, child: listPane),
            const VerticalDivider(width: 1),
            Expanded(
              child: editing == null
                  ? const EmptyState(icon: Icons.edit_note_rounded, title: 'Select or create a note', message: 'Your notes are stored on this device and searchable instantly.')
                  : NoteEditor(key: ValueKey(editing!.id), note: editing!, onClose: () => setState(() => editing = null)),
            ),
          ]);
        },
      ),
    );
  }
}
