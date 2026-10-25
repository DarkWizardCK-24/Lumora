import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'schema.dart';

const _uuid = Uuid();

String newId() => _uuid.v4();

/// Tables whose rows replicate to the cloud (see SYNC_DESIGN.md).
const syncedTables = <String>{
  'subjects',
  'topics',
  'learning_goals',
  'goal_milestones',
  'study_sessions',
  'session_pauses',
  'scheduled_activities',
  'coding_problems',
  'notes',
};

/// Owns the SQLite connection and exposes a change stream so providers refresh.
class AppDatabase {
  AppDatabase._(this.db, this.path);
  final Database db;
  final String path;
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  void notifyChanged() => _changes.add(null);

  static bool get _useFfi =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static Future<String> defaultPath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'lumora.db');
  }

  /// Opens (and migrates) the database. [path] may be [inMemoryDatabasePath].
  static Future<AppDatabase> open({String? path}) async {
    if (_useFfi) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dbPath = path ?? await defaultPath();
    final db = await openDatabase(
      dbPath,
      version: schemaVersion,
      onConfigure: (d) async => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, v) async => _migrate(d, 0, v),
      onUpgrade: (d, o, n) async => _migrate(d, o, n),
    );
    return AppDatabase._(db, dbPath);
  }

  static Future<void> _migrate(Database d, int from, int to) async {
    await d.transaction((txn) async {
      await txn.execute(
          'CREATE TABLE IF NOT EXISTS schema_migrations(version INTEGER PRIMARY KEY, applied_at INTEGER NOT NULL)');
      for (var v = from; v < to; v++) {
        for (final sql in schemaMigrations[v]) {
          await txn.execute(sql);
        }
        await txn.insert('schema_migrations',
            {'version': v + 1, 'applied_at': DateTime.now().millisecondsSinceEpoch});
      }
    });
  }

  Future<void> close() async {
    await _changes.close();
    await db.close();
  }

  // ---------------------------------------------------------------- DAO ---

  Future<List<Map<String, Object?>>> query(String table,
          {String? where, List<Object?>? args, String? orderBy, int? limit}) =>
      db.query(table, where: where, whereArgs: args, orderBy: orderBy, limit: limit);

  Future<Map<String, Object?>?> byId(String table, String id) async {
    final r = await db.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : r.first;
  }

  Future<List<Map<String, Object?>>> raw(String sql, [List<Object?>? args]) =>
      db.rawQuery(sql, args);

  /// Inserts or updates a row and (for synced tables) enqueues an outbox
  /// operation in the SAME transaction, so a crash can never separate them.
  Future<void> upsert(String table, Map<String, Object?> row, {DatabaseExecutor? exec}) async {
    Future<void> work(DatabaseExecutor t) async {
      final id = row['id'] as String;
      final existing = await t.query(table, columns: ['id', if (_hasVersion(table)) 'version'], where: 'id = ?', whereArgs: [id]);
      final data = Map<String, Object?>.from(row);
      if (existing.isEmpty) {
        await t.insert(table, data);
      } else {
        if (_hasVersion(table)) data['version'] = ((existing.first['version'] as int?) ?? 1) + 1;
        await t.update(table, data, where: 'id = ?', whereArgs: [id]);
      }
      if (syncedTables.contains(table)) {
        final full = (await t.query(table, where: 'id = ?', whereArgs: [id])).first;
        await _enqueue(t, table, id, 'upsert', full);
      }
    }

    if (exec != null) {
      await work(exec);
    } else {
      await db.transaction((t) => work(t));
    }
    notifyChanged();
  }

  bool _hasVersion(String t) => syncedTables.contains(t);

  Future<void> delete(String table, String id) async {
    await db.transaction((t) async {
      await t.delete(table, where: 'id = ?', whereArgs: [id]);
      if (syncedTables.contains(table)) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await t.insert('deletion_tombstones',
            {'entity_type': table, 'entity_id': id, 'deleted_at': now},
            conflictAlgorithm: ConflictAlgorithm.replace);
        await _enqueue(t, table, id, 'delete', {'id': id, 'deleted_at': now});
      }
    });
    notifyChanged();
  }

  Future<void> _enqueue(DatabaseExecutor t, String type, String id, String op,
      Map<String, Object?> payload) async {
    // Collapse older pending ops for the same entity: only the newest state matters.
    await t.delete('sync_outbox',
        where: "entity_type = ? AND entity_id = ? AND status = 'pending'", whereArgs: [type, id]);
    await t.insert('sync_outbox', {
      'id': newId(),
      'entity_type': type,
      'entity_id': id,
      'op': op,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Runs several writes atomically; notifies listeners once.
  Future<T> transaction<T>(Future<T> Function(Transaction t) action) async {
    final r = await db.transaction(action);
    notifyChanged();
    return r;
  }

  // ------------------------------------------------------- preferences ---

  Future<String?> pref(String key) async {
    final r = await db.query('user_preferences', where: 'key = ?', whereArgs: [key]);
    return r.isEmpty ? null : r.first['value'] as String;
  }

  Future<void> setPref(String key, String value) async {
    await db.insert('user_preferences', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
    notifyChanged();
  }

  Future<String?> meta(String key) async {
    final r = await db.query('sync_metadata', where: 'key = ?', whereArgs: [key]);
    return r.isEmpty ? null : r.first['value'] as String;
  }

  Future<void> setMeta(String key, String value) => db.insert(
      'sync_metadata', {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace);
}
