import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/colors/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/services/app_database.dart';
import '../../core/services/remote_store.dart';
import '../../core/services/sync_service.dart';
import '../../core/utils/format.dart';
import '../utils/app_snack.dart';
import 'confirmation_dialog.dart';
import 'form_dialog.dart';
import 'pill.dart';
import 'section_card.dart';

/// Account, cloud sync and conflict resolution. The app is fully usable
/// without signing in; sync only replicates what is already saved locally.
class AccountSyncCard extends ConsumerStatefulWidget {
  const AccountSyncCard({super.key});
  @override
  ConsumerState<AccountSyncCard> createState() => _AccountSyncCardState();
}

class _AccountSyncCardState extends ConsumerState<AccountSyncCard> {
  bool _busy = false;

  Future<void> _auth(bool signUp) async {
    final v = await showForm(context,
        title: signUp ? 'Create account' : 'Sign in',
        submitLabel: signUp ? 'Create account' : 'Sign in',
        fields: const [
          FText('email', 'Email', required: true, keyboard: TextInputType.emailAddress),
          FText('password', 'Password', required: true, obscure: true),
        ]);
    if (v == null) return;
    setState(() => _busy = true);
    final remote = ref.read(remoteProvider);
    try {
      final email = (v['email'] as String).trim();
      signUp ? await remote.signUp(email, v['password'] as String) : await remote.signIn(email, v['password'] as String);
      if (!mounted) return;
      await _initialSync();
    } on SyncException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// First sign-in on a device with data: let the user choose; nothing is overwritten.
  Future<void> _initialSync() async {
    final db = ref.read(dbProvider);
    var hasLocal = false;
    for (final t in syncedTables) {
      if ((await db.query(t, limit: 1)).isNotEmpty) hasLocal = true;
    }
    final sync = ref.read(syncProvider);
    if (!hasLocal) {
      await sync.syncNow();
      return;
    }
    if (!mounted) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('This device already has data'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: const Text('How should your local records and your cloud account be combined?\n\n'
              '• Merge: uploads local records and downloads cloud records. Nothing is overwritten; true conflicts are shown for you to resolve.\n'
              '• Back up first, then merge: same, after saving a backup file.\n'
              '• Keep local-only: stay signed in but do not sync this device.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 'local'), child: const Text('Keep local-only')),
          OutlinedButton(onPressed: () => Navigator.pop(c, 'backup'), child: const Text('Back up, then merge')),
          FilledButton(onPressed: () => Navigator.pop(c, 'merge'), child: const Text('Merge')),
        ],
      ),
    );
    if (choice == null || choice == 'local') {
      await ref.read(settingsProvider.notifier).update(ref.read(settingsProvider).copyWith(syncEnabled: false));
      ref.read(syncProvider).enabled = false;
      await sync.refreshStatus();
      return;
    }
    if (choice == 'backup') {
      final path = await ref.read(backupProvider).createBackup();
      if (mounted) toast(context, 'Backup saved to $path');
    }
    await sync.queueFullUpload();
    await sync.syncNow();
  }

  Future<void> _signOut(SyncStatus st) async {
    final ok = await confirm(
        context,
        'Sign out?',
        st.pending > 0
            ? 'You have ${st.pending} changes that have not been uploaded yet. They stay safely on this device and will upload the next time you sign in. Your local data is not deleted.'
            : 'Your local data stays on this device. You can sign in again at any time.',
        action: 'Sign out',
        destructive: false);
    if (!ok) return;
    await ref.read(remoteProvider).signOut();
    await ref.read(syncProvider).refreshStatus();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final remote = ref.watch(remoteProvider);
    final settings = ref.watch(settingsProvider);
    final sync = ref.watch(syncProvider);
    final st = ref.watch(syncStatusProvider).value ?? const SyncStatus(SyncState.localOnly);
    return SectionCard(
      title: 'Account & cloud sync',
      trailing: Pill(st.label, color: st.state == SyncState.failed ? Palette.danger : Theme.of(context).colorScheme.primary),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!firebaseConfigured)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Palette.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(Radii.sm)),
            child: const Text('Cloud sync is not configured in this build, so Lumora runs in local-only mode. '
                'Build with --dart-define=FIREBASE_API_KEY=… and --dart-define=FIREBASE_PROJECT_ID=… to enable it (see SYNC_DESIGN.md).'),
          )
        else if (!remote.signedIn)
          const Text('Sign in to back up and sync across devices. Everything keeps working offline without an account.',
              style: TextStyle(color: Palette.muted))
        else
          Text('Signed in as ${remote.email}', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          if (firebaseConfigured && !remote.signedIn) ...[
            FilledButton(onPressed: _busy ? null : () => _auth(false), child: const Text('Sign in')),
            OutlinedButton(onPressed: _busy ? null : () => _auth(true), child: const Text('Create account')),
          ],
          if (remote.signedIn) ...[
            FilledButton.icon(onPressed: _busy ? null : () => sync.syncNow(), icon: const Icon(Icons.sync), label: const Text('Sync now')),
            if (st.failed > 0) OutlinedButton(onPressed: sync.retryFailed, child: const Text('Retry failed')),
            OutlinedButton(onPressed: () => _signOut(st), child: const Text('Sign out')),
          ],
        ]),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sync this device'),
          subtitle: const Text('Turn off for local-only mode. Pending changes are kept.'),
          value: settings.syncEnabled,
          onChanged: (v) async {
            await ref.read(settingsProvider.notifier).update(settings.copyWith(syncEnabled: v));
            sync.enabled = v;
            await sync.refreshStatus();
          },
        ),
        const Divider(),
        _kv('Pending changes', '${st.pending}'),
        _kv('Failed operations', '${st.failed}'),
        _kv('Last successful sync', st.lastSync == null ? 'never' : fmtDateTime(st.lastSync!)),
        if (st.lastError != null) _kv('Last error', st.lastError!, color: Palette.danger),
        if (st.conflicts > 0) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
              onPressed: () => _resolveConflicts(context),
              icon: const Icon(Icons.merge_type),
              label: Text('Resolve ${st.conflicts} conflict${st.conflicts == 1 ? '' : 's'}')),
        ],
      ]),
    );
  }

  Widget _kv(String k, String v, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(k, style: const TextStyle(color: Palette.muted))),
          Flexible(child: Text(v, textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w600, color: color))),
        ]),
      );

  Future<void> _resolveConflicts(BuildContext context) async {
    final sync = ref.read(syncProvider);
    final list = await sync.conflictList();
    if (!context.mounted) return;
    for (final c in list) {
      final title = (c.local['title'] ?? c.local['name'] ?? c.id).toString();
      final keepLocal = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text('Conflict in ${c.type.replaceAll('_', ' ')}'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text('"$title" was edited on this device and elsewhere.\n\n'
                'This device: ${_summary(c.local)}\nCloud: ${_summary(c.remote)}'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Decide later')),
            OutlinedButton(onPressed: () => Navigator.pop(d, false), child: const Text('Use cloud version')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Keep this device')),
          ],
        ),
      );
      if (keepLocal == null) break;
      await sync.resolveConflict(c, keepLocal: keepLocal);
    }
  }

  String _summary(Map<String, Object?> r) {
    final up = r['updated_at'];
    final when = up is int ? fmtDateTime(DateTime.fromMillisecondsSinceEpoch(up)) : '?';
    return 'edited $when (v${r['version'] ?? '?'})';
  }
}
