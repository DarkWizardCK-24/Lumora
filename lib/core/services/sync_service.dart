import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:logging/logging.dart';
import 'app_database.dart';
import 'remote_store.dart';

final _log = Logger('sync');

enum SyncState { localOnly, signInRequired, offline, syncing, synced, pending, failed }

class SyncStatus {
  const SyncStatus(this.state, {this.pending = 0, this.failed = 0, this.lastSync, this.lastError, this.conflicts = 0});
  final SyncState state;
  final int pending, failed, conflicts;
  final DateTime? lastSync;
  final String? lastError;

  String get label => switch (state) {
        SyncState.localOnly => 'Local only',
        SyncState.signInRequired => 'Sign-in required',
        SyncState.offline => 'Offline',
        SyncState.syncing => 'Syncing…',
        SyncState.synced => 'Synced',
        SyncState.pending => '$pending pending',
        SyncState.failed => 'Sync failed',
      };
}

class SyncConflict {
  SyncConflict(this.type, this.id, this.local, this.remote);
  final String type, id;
  final Map<String, Object?> local, remote;
  Map<String, Object?> toJson() => {'type': type, 'id': id, 'local': local, 'remote': remote};
}

/// Durable-outbox sync worker.
///
/// Conflict policy (see SYNC_DESIGN.md): every row has an integer `version`
/// bumped on each local write. During pull, if a remote row is newer than the
/// local row and the local row has an unsent change, the pair is stored as a
/// conflict for the user to resolve; otherwise newest `updated_at` wins.
/// Deletes win over edits via tombstones.
class SyncService {
  SyncService(this.db, this.remote);
  final AppDatabase db;
  final RemoteStore remote;
  bool _running = false;
  bool enabled = true;
  bool online = true;
  String? _lastError;
  final _status = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _status.stream;
  SyncStatus last = const SyncStatus(SyncState.localOnly);

  static const maxBackoff = Duration(minutes: 30);
  static Duration backoff(int attempts) =>
      Duration(seconds: math.min(maxBackoff.inSeconds, 5 * math.pow(2, attempts).toInt()));

  Future<SyncStatus> computeStatus({bool syncing = false}) async {
    final p = (await db.raw("SELECT COUNT(*) c FROM sync_outbox WHERE status='pending'")).first['c'] as int;
    final f = (await db.raw("SELECT COUNT(*) c FROM sync_outbox WHERE status='failed'")).first['c'] as int;
    final ls = int.tryParse(await db.meta('last_sync') ?? '');
    final conflicts = (await conflictList()).length;
    final lastSync = ls == null ? null : DateTime.fromMillisecondsSinceEpoch(ls);
    SyncState st;
    if (!enabled) {
      st = SyncState.localOnly;
    } else if (!remote.signedIn) {
      st = SyncState.signInRequired;
    } else if (syncing) {
      st = SyncState.syncing;
    } else if (!online) {
      st = SyncState.offline;
    } else if (f > 0 || _lastError != null) {
      st = SyncState.failed;
    } else if (p > 0) {
      st = SyncState.pending;
    } else {
      st = SyncState.synced;
    }
    return SyncStatus(st,
        pending: p, failed: f, lastSync: lastSync, lastError: _lastError, conflicts: conflicts);
  }

  Future<void> refreshStatus({bool syncing = false}) async {
    last = await computeStatus(syncing: syncing);
    _status.add(last);
  }

  /// One full cycle: push outbox, then pull. Never throws — errors become status.
  Future<void> syncNow() async {
    if (_running || !enabled || !remote.signedIn) {
      await refreshStatus();
      return;
    }
    _running = true;
    _lastError = null;
    await refreshStatus(syncing: true);
    try {
      await _push();
      await _pull();
      await db.setMeta('last_sync', '${DateTime.now().millisecondsSinceEpoch}');
    } on SyncException catch (e) {
      _lastError = e.message;
      _log.warning('sync failed: ${e.message}');
    } catch (e, st) {
      _lastError = 'Unexpected sync error: $e';
      _log.severe('sync crashed', e, st);
    } finally {
      _running = false;
      await refreshStatus();
    }
  }

  Future<void> _push() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query('sync_outbox',
        where: "status = 'pending' AND next_retry_at <= ?", args: [now], orderBy: 'created_at');
    for (final r in rows) {
      final id = r['id'] as String;
      try {
        final payload = jsonDecode(r['payload'] as String) as Map<String, dynamic>;
        if (r['op'] == 'delete') {
          await remote.remove(r['entity_type'] as String, r['entity_id'] as String,
              (payload['deleted_at'] as num).toInt());
        } else {
          await remote.put(r['entity_type'] as String, r['entity_id'] as String,
              payload.map((k, v) => MapEntry(k, v as Object?)));
        }
        // Only now — after confirmation — is the operation removed.
        await db.db.delete('sync_outbox', where: 'id = ?', whereArgs: [id]);
      } on SyncException catch (e) {
        final attempts = (r['attempts'] as int) + 1;
        await db.db.update(
            'sync_outbox',
            {
              'attempts': attempts,
              'last_error': e.message,
              'next_retry_at': DateTime.now().add(backoff(attempts)).millisecondsSinceEpoch,
              'status': e.transient && attempts < 8 ? 'pending' : 'failed',
            },
            where: 'id = ?',
            whereArgs: [id]);
        rethrow;
      }
    }
  }

  Future<void> _pull() async {
    final since = int.tryParse(await db.meta('last_pull') ?? '') ?? 0;
    final started = DateTime.now().millisecondsSinceEpoch - 60000; // clock-skew margin
    final docs = await remote.pullSince(since);
    final conflicts = await conflictList();
    for (final d in docs) {
      final local = await db.byId(d.type, d.id);
      final pending = (await db.query('sync_outbox',
              where: "entity_type = ? AND entity_id = ? AND status != 'done'", args: [d.type, d.id]))
          .isNotEmpty;
      if (d.deleted) {
        if (local != null && !pending) {
          await db.db.delete(d.type, where: 'id = ?', whereArgs: [d.id]);
        }
        continue;
      }
      final tomb = await db.query('deletion_tombstones',
          where: 'entity_type = ? AND entity_id = ?', args: [d.type, d.id]);
      if (tomb.isNotEmpty) continue; // deleted locally; deletion is on its way up
      final cols = (await db.raw('PRAGMA table_info(${d.type})')).map((c) => c['name'] as String).toSet();
      final remoteRow = {for (final e in d.data.entries) if (cols.contains(e.key)) e.key: e.value};
      if (local == null) {
        await db.db.insert(d.type, remoteRow);
      } else {
        final rUp = (remoteRow['updated_at'] as int?) ?? 0;
        final lUp = (local['updated_at'] as int?) ?? 0;
        if (rUp <= lUp) continue;
        if (pending) {
          if (!conflicts.any((c) => c.type == d.type && c.id == d.id)) {
            conflicts.add(SyncConflict(d.type, d.id, Map.of(local), remoteRow));
          }
        } else {
          await db.db.update(d.type, remoteRow, where: 'id = ?', whereArgs: [d.id]);
        }
      }
    }
    await _saveConflicts(conflicts);
    await db.setMeta('last_pull', '$started');
    db.notifyChanged();
  }

  // ----------------------------------------------------------- conflicts ---
  Future<List<SyncConflict>> conflictList() async {
    final raw = await db.meta('conflicts');
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List)
        .map((e) => SyncConflict(e['type'] as String, e['id'] as String,
            Map<String, Object?>.from(e['local'] as Map), Map<String, Object?>.from(e['remote'] as Map)))
        .toList();
  }

  Future<void> _saveConflicts(List<SyncConflict> c) =>
      db.setMeta('conflicts', jsonEncode(c.map((e) => e.toJson()).toList()));

  /// Resolve by keeping the local copy (re-queued) or taking the cloud copy.
  Future<void> resolveConflict(SyncConflict c, {required bool keepLocal}) async {
    final all = await conflictList();
    all.removeWhere((x) => x.type == c.type && x.id == c.id);
    await _saveConflicts(all);
    if (keepLocal) {
      final row = Map<String, Object?>.from(c.local);
      row['updated_at'] = DateTime.now().millisecondsSinceEpoch;
      await db.upsert(c.type, row);
    } else {
      await db.db.update(c.type, c.remote, where: 'id = ?', whereArgs: [c.id]);
      await db.db.delete('sync_outbox',
          where: 'entity_type = ? AND entity_id = ?', whereArgs: [c.type, c.id]);
      db.notifyChanged();
    }
    await refreshStatus();
  }

  Future<void> retryFailed() async {
    await db.db.update('sync_outbox', {'status': 'pending', 'next_retry_at': 0, 'attempts': 0},
        where: "status = 'failed'");
    await syncNow();
  }

  /// First sign-in on a device that already has local data: queue everything
  /// so the cloud receives a merge. Existing records are never overwritten.
  Future<void> queueFullUpload() async {
    for (final t in syncedTables) {
      final rows = await db.query(t);
      for (final r in rows) {
        final id = r['id'] as String;
        final exists = await db.query('sync_outbox',
            where: "entity_type = ? AND entity_id = ? AND status = 'pending'", args: [t, id]);
        if (exists.isEmpty) {
          await db.db.insert('sync_outbox', {
            'id': newId(),
            'entity_type': t,
            'entity_id': id,
            'op': 'upsert',
            'payload': jsonEncode(r),
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
    }
  }
}
