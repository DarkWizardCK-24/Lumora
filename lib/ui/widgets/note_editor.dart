import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors/app_colors.dart';
import '../../core/models/note.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/repository.dart';
import '../../core/utils/pickers.dart';
import 'confirmation_dialog.dart';
import 'pill.dart';
import 'simple_markdown.dart';

class NoteEditor extends ConsumerStatefulWidget {
  const NoteEditor({super.key, required this.note, required this.onClose});
  final Note note;
  final VoidCallback onClose;
  @override
  ConsumerState<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<NoteEditor> {
  late final _title = TextEditingController(text: widget.note.title);
  late final _body = TextEditingController(text: widget.note.body);
  late final _tags = TextEditingController(text: widget.note.tags);
  Timer? _debounce;
  bool _dirty = false, _preview = false, _failed = false, _exists = false;
  late final repo = ref.read(repoProvider);

  @override
  void initState() {
    super.initState();
    _exists = widget.note.updatedAt != widget.note.createdAt || widget.note.title.isNotEmpty || widget.note.body.isNotEmpty;
  }

  void _changed() {
    setState(() {
      _dirty = true;
      _failed = false;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), save);
  }

  bool get _blank => _title.text.trim().isEmpty && _body.text.trim().isEmpty;

  Future<void> save() async {
    _debounce?.cancel();
    if (!_dirty || (_blank && !_exists)) return;
    final n = widget.note
      ..title = _title.text.trim().isEmpty ? 'Untitled' : _title.text.trim()
      ..body = _body.text
      ..tags = _tags.text;
    try {
      await repo.saveNote(n);
      _exists = true;
      if (mounted) setState(() => _dirty = false);
    } catch (e) {
      // Keep the content in the editor and tell the user — never drop it silently.
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_dirty && !(_blank && !_exists)) {
      // Last-chance save so navigating away never loses text.
      final n = widget.note
        ..title = _title.text.trim().isEmpty ? 'Untitled' : _title.text.trim()
        ..body = _body.text
        ..tags = _tags.text;
      unawaited(repo.saveNote(n));
    }
    _title.dispose();
    _body.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(snapshotProvider).value;
    final n = widget.note;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.keyS, control: true): save},
      child: Focus(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _title,
                  onChanged: (_) => _changed(),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(hintText: 'Title', border: InputBorder.none, enabledBorder: InputBorder.none, filled: false),
                ),
              ),
              IconButton(
                  tooltip: n.favorite ? 'Unfavorite' : 'Favorite',
                  icon: Icon(n.favorite ? Icons.star_rounded : Icons.star_outline_rounded, color: n.favorite ? Palette.warning : null),
                  onPressed: () async {
                    n.favorite = !n.favorite;
                    _dirty = true;
                    await save();
                    setState(() {});
                  }),
              IconButton(
                  tooltip: _preview ? 'Edit' : 'Preview Markdown',
                  icon: Icon(_preview ? Icons.edit_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _preview = !_preview)),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  await save();
                  if (!context.mounted) return;
                  if (v == 'archive') {
                    n.archived = !n.archived;
                    await repo.saveNote(n);
                    widget.onClose();
                  } else if (v == 'delete' && await confirm(context, 'Delete note?', 'This cannot be undone.')) {
                    _dirty = false;
                    await repo.deleteNote(n.id);
                    widget.onClose();
                  } else if (v == 'close') {
                    widget.onClose();
                  }
                },
                itemBuilder: (c) => [
                  PopupMenuItem(value: 'archive', child: Text(n.archived ? 'Restore' : 'Archive')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  const PopupMenuItem(value: 'close', child: Text('Close')),
                ],
              ),
            ]),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Pill(_failed ? 'Save failed — content kept' : _dirty ? 'Unsaved changes' : 'Saved', color: _failed ? Palette.danger : _dirty ? Palette.warning : Palette.success, icon: _failed ? Icons.error_outline : _dirty ? Icons.edit : Icons.check_circle_outline),
              if (snap != null)
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String?>(
                    initialValue: n.subjectId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Subject', isDense: true),
                    items: [const DropdownMenuItem(value: null, child: Text('None')), for (final e in subjectOptions(snap).entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))],
                    onChanged: (v) {
                      n.subjectId = v;
                      _changed();
                    },
                  ),
                ),
              if (snap != null)
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String?>(
                    initialValue: n.goalId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Goal', isDense: true),
                    items: [const DropdownMenuItem(value: null, child: Text('None')), for (final e in goalOptions(snap).entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))],
                    onChanged: (v) {
                      n.goalId = v;
                      _changed();
                    },
                  ),
                ),
              SizedBox(
                width: 200,
                child: TextField(controller: _tags, onChanged: (_) => _changed(), decoration: const InputDecoration(labelText: 'Tags (comma separated)', isDense: true)),
              ),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: _preview
                  ? SingleChildScrollView(child: SimpleMarkdown(_body.text))
                  : TextField(
                      controller: _body,
                      onChanged: (_) => _changed(),
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(hintText: 'Write in Markdown: # heading, **bold**, - list, `code`'),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
