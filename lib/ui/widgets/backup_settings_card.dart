import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/colors/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../utils/app_snack.dart';
import 'confirmation_dialog.dart';
import 'section_card.dart';

/// Backup, restore, export and explicit local-data deletion.
class BackupSettingsCard extends ConsumerStatefulWidget {
  const BackupSettingsCard({super.key});
  @override
  ConsumerState<BackupSettingsCard> createState() => _BackupSettingsCardState();
}

class _BackupSettingsCardState extends ConsumerState<BackupSettingsCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
    } on FormatException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (e) {
      if (mounted) toast(context, 'Something went wrong: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backup() => _run(() async {
        final path = await ref.read(backupProvider).createBackup();
        if (mounted) toast(context, 'Backup saved: $path');
      });

  Future<void> _restore() => _run(() async {
        final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
        final path = picked.isEmpty ? null : picked.first.path;
        if (path == null) return;
        final content = await File(path).readAsString();
        final svc = ref.read(backupProvider);
        final p = await svc.preview(content);
        if (!mounted) return;
        final ok = await confirm(
            context,
            'Restore backup?',
            'Backup from ${p.createdAt?.toLocal().toString().split('.').first ?? 'unknown date'}.\n\n'
                '${p.totalNew} new records will be added. ${p.totalDuplicates} records already exist and will be skipped — '
                'nothing is overwritten. A safety backup of your current data is saved first, and the restore is all-or-nothing.',
            action: 'Restore',
            destructive: false);
        if (!ok) return;
        final r = await svc.restore(content);
        if (mounted) toast(context, 'Restored ${r.added} records (${r.skipped} skipped). Safety copy: ${r.safetyBackup}');
      });

  Future<void> _export(bool pdf) => _run(() async {
        final dir = await FilePicker.getDirectoryPath(dialogTitle: 'Choose export folder');
        if (dir == null) return;
        final snap = await ref.read(snapshotProvider.future);
        final svc = ref.read(backupProvider);
        final path = pdf ? await svc.exportPdf(dir, snap) : await svc.exportCsv(dir, snap);
        if (mounted) toast(context, 'Exported to $path');
      });

  Future<void> _wipe() async {
    final ok = await confirm(
        context,
        'Delete ALL local data?',
        'This permanently deletes every subject, goal, session, note, problem and plan on this device, including pending sync changes. '
            'Create a backup first if you might want it back. Signing out never does this — only this button.',
        action: 'Delete everything');
    if (!ok) return;
    await _run(() async {
      await ref.read(backupProvider).deleteAllLocalData();
      if (mounted) toast(context, 'Local data deleted');
    });
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Backup, restore & export',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Backups are versioned JSON files. Restoring merges records by ID and never silently overwrites existing data.',
            style: TextStyle(color: Palette.muted)),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(onPressed: _busy ? null : _backup, icon: const Icon(Icons.backup_outlined), label: const Text('Create backup')),
          OutlinedButton.icon(onPressed: _busy ? null : _restore, icon: const Icon(Icons.restore_page_outlined), label: const Text('Restore from file')),
          OutlinedButton.icon(onPressed: _busy ? null : () => _export(false), icon: const Icon(Icons.table_chart_outlined), label: const Text('Export CSV')),
          OutlinedButton.icon(onPressed: _busy ? null : () => _export(true), icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('PDF report')),
        ]),
        const SizedBox(height: 18),
        const Divider(),
        const SizedBox(height: 10),
        OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Palette.danger, side: const BorderSide(color: Palette.danger)),
            onPressed: _busy ? null : _wipe,
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete all local data…')),
      ]),
    );
  }
}
