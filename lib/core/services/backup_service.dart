import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/enums.dart';
import 'app_database.dart';
import 'goal_analyzer.dart';
import 'schema.dart';
import 'snapshot.dart';
import 'streak_engine.dart';
import 'weekly_review_service.dart';
import '../utils/date_format.dart';

const backupFormatVersion = 1;

/// Parents before children so foreign keys are satisfied during restore.
const _restoreOrder = [
  'subjects',
  'learning_goals',
  'topics',
  'goal_milestones',
  'study_sessions',
  'session_pauses',
  'scheduled_activities',
  'coding_problems',
  'problem_attempts',
  'flashcards',
  'flashcard_reviews',
  'notes',
  'tags',
  'note_tags',
  'achievements',
  'study_availability',
  'weekly_reviews',
];

const _keyOf = {
  'achievements': 'code',
  'study_availability': 'weekday',
  'note_tags': 'note_id',
};

class RestorePreview {
  RestorePreview(this.newRows, this.duplicates, this.version, this.createdAt);
  final Map<String, int> newRows, duplicates;
  final int version;
  final DateTime? createdAt;
  int get totalNew => newRows.values.fold(0, (a, b) => a + b);
  int get totalDuplicates => duplicates.values.fold(0, (a, b) => a + b);
}

class BackupService {
  BackupService(this.db);
  final AppDatabase db;

  Future<Directory> backupDir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(base.path, 'Lumora', 'backups'));
    await d.create(recursive: true);
    return d;
  }

  Future<Map<String, dynamic>> snapshotJson() async {
    final tables = <String, dynamic>{};
    for (final t in _restoreOrder) {
      tables[t] = await db.query(t);
    }
    final prefs = await db.query('user_preferences');
    return {
      'app': 'Lumora',
      'format': backupFormatVersion,
      'schema': schemaVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
      'preferences': prefs,
    };
  }

  /// Writes a backup file and returns its path.
  Future<String> createBackup({String? directory, String prefix = 'lumora-backup'}) async {
    final dir = directory ?? (await backupDir()).path;
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File(p.join(dir, '$prefix-$stamp.json'));
    await file.writeAsString(const JsonEncoder.withIndent(' ').convert(await snapshotJson()));
    return file.path;
  }

  Map<String, dynamic> _parse(String content) {
    final Object? j;
    try {
      j = jsonDecode(content);
    } on FormatException {
      throw const FormatException('This file is not valid JSON.');
    }
    if (j is! Map || j['app'] != 'Lumora' || j['tables'] is! Map) {
      throw const FormatException('This is not a Lumora backup file.');
    }
    if ((j['format'] as int? ?? 0) > backupFormatVersion) {
      throw const FormatException('This backup was made by a newer version of Lumora.');
    }
    return Map<String, dynamic>.from(j);
  }

  Future<RestorePreview> preview(String content) async {
    final j = _parse(content);
    final tables = j['tables'] as Map;
    final newRows = <String, int>{}, dups = <String, int>{};
    for (final t in _restoreOrder) {
      final rows = (tables[t] as List? ?? []).cast<Map>();
      var n = 0, d = 0;
      for (final r in rows) {
        (await _exists(db.db, t, r)) ? d++ : n++;
      }
      if (n > 0) newRows[t] = n;
      if (d > 0) dups[t] = d;
    }
    return RestorePreview(newRows, dups, j['format'] as int? ?? 1,
        DateTime.tryParse(j['createdAt'] as String? ?? ''));
  }

  Future<bool> _exists(dynamic exec, String t, Map r) async {
    if (t == 'note_tags') {
      return (await exec.query(t,
              where: 'note_id = ? AND tag_id = ?', whereArgs: [r['note_id'], r['tag_id']]))
          .isNotEmpty;
    }
    final key = _keyOf[t] ?? 'id';
    return (await exec.query(t, where: '$key = ?', whereArgs: [r[key]])).isNotEmpty;
  }

  /// Merge-restore: existing records are never overwritten; duplicates are
  /// skipped. Everything happens in one transaction so a failure rolls back.
  /// A safety backup of current data is written first.
  Future<({int added, int skipped, String safetyBackup})> restore(String content) async {
    final j = _parse(content);
    final safety = await createBackup(prefix: 'pre-restore');
    final tables = j['tables'] as Map;
    var added = 0, skipped = 0;
    await db.transaction((t) async {
      for (final name in _restoreOrder) {
        for (final r in (tables[name] as List? ?? []).cast<Map>()) {
          if (await _exists(t, name, r)) {
            skipped++;
            continue;
          }
          if (name == 'tags') {
            final byName = await t.query('tags', where: 'name = ?', whereArgs: [r['name']]);
            if (byName.isNotEmpty) {
              skipped++;
              continue;
            }
          }
          await t.insert(name, Map<String, Object?>.from(r));
          added++;
        }
      }
    });
    return (added: added, skipped: skipped, safetyBackup: safety);
  }

  // --------------------------------------------------------------- exports

  Future<String> exportCsv(String directory, Snapshot s) async {
    final names = {for (final x in s.subjects) x.id: x.name};
    final rows = <List<dynamic>>[
      ['Date', 'Subject', 'Type', 'Minutes', 'Notes'],
      for (final x in s.sessions)
        [
          dateKey(fromMs(x.startedAt)),
          names[x.subjectId] ?? '',
          x.type.label,
          x.activeSeconds ~/ 60,
          x.notes,
        ],
    ];
    final f = File(p.join(directory, 'lumora-sessions.csv'));
    await f.writeAsString(Csv().encode(rows));
    final prob = <List<dynamic>>[
      ['Title', 'Platform', 'Difficulty', 'Result', 'Minutes', 'Date', 'URL'],
      for (final x in s.problems)
        [x.title, x.platform, x.difficulty, x.result.label, x.minutes, dateKey(fromMs(x.attemptedAt)), x.url],
    ];
    await File(p.join(directory, 'lumora-coding.csv'))
        .writeAsString(Csv().encode(prob));
    return f.path;
  }

  Future<String> exportPdf(String directory, Snapshot s) async {
    final doc = pw.Document();
    final streak = StreakEngine.compute(s);
    final hours = (s.totalMinutes / 60).toStringAsFixed(1);
    final week = s.today.subtract(Duration(days: s.today.weekday - 1));
    final review = WeeklyReview.build(s, week);
    doc.addPage(pw.MultiPage(
      build: (c) => [
        pw.Text('Lumora learning report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.Text('Generated ${dateKey(s.now)}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(data: [
          ['Total learning hours', hours],
          ['Current streak', '${streak.current} days'],
          ['Longest streak', '${streak.longest} days'],
          ['Problems solved', '${s.problems.where((p) => p.result == ProblemResult.solved).length}'],
          ['This week (hours)', (review.actualMinutes / 60).toStringAsFixed(1)],
        ]),
        pw.SizedBox(height: 16),
        pw.Text('Goals', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.TableHelper.fromTextArray(
          headers: ['Goal', 'Status', 'Progress', 'Deadline'],
          data: [
            for (final g in s.goals)
              [
                g.title,
                GoalAnalyzer.analyze(g, s).status.label,
                '${(GoalAnalyzer.progressOf(g, s) * 100).round()}%',
                g.deadline == null ? '—' : dateKey(g.deadline!),
              ]
          ],
        ),
      ],
      pageFormat: PdfPageFormat.a4,
    ));
    final f = File(p.join(directory, 'lumora-report.pdf'));
    await f.writeAsBytes(await doc.save());
    return f.path;
  }

  /// Explicit, confirmed wipe of all learning data (preferences are kept).
  Future<void> deleteAllLocalData() async {
    await db.transaction((t) async {
      for (final name in _restoreOrder.reversed) {
        await t.delete(name);
      }
      await t.delete('sync_outbox');
      await t.delete('deletion_tombstones');
      await t.delete('coaching_tip_history');
      await t.delete('schedule_revisions');
    });
  }
}
