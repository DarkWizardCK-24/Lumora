import '../models/note.dart';
import 'app_database.dart';
import 'repository.dart';

extension NotesService on Repository {
  Future<List<Note>> notes({String? query}) async {
    final q = query?.trim() ?? '';
    final rows = q.isEmpty
        ? await db.query('notes', orderBy: 'favorite DESC, updated_at DESC')
        : await db.query('notes',
            where: 'title LIKE ? OR body LIKE ? OR tags LIKE ?',
            args: ['%$q%', '%$q%', '%$q%'],
            orderBy: 'favorite DESC, updated_at DESC');
    return mapRows(rows, Note.fromMap);
  }

  Future<void> saveNote(Note n) async {
    await db.transaction((t) async {
      await db.upsert('notes', n.toMap(), exec: t);
      await t.delete('note_tags', where: 'note_id = ?', whereArgs: [n.id]);
      for (final tag in n.tagList) {
        final ex = await t.query('tags', where: 'name = ?', whereArgs: [tag]);
        final tagId = ex.isEmpty ? newId() : ex.first['id'] as String;
        if (ex.isEmpty) await t.insert('tags', {'id': tagId, 'name': tag});
        await t.insert('note_tags', {'note_id': n.id, 'tag_id': tagId});
      }
    });
  }

  Future<void> deleteNote(String id) => db.delete('notes', id);

}
