import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors/app_colors.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/services/remote_store.dart';
import '../../core/services/sync_service.dart';
import '../../core/utils/format.dart';
import 'pill.dart';

class SyncChip extends ConsumerWidget {
  const SyncChip({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(syncStatusProvider).value ?? const SyncStatus(SyncState.localOnly);
    final (icon, color) = switch (st.state) {
      SyncState.synced => (Icons.cloud_done_outlined, Palette.success),
      SyncState.syncing => (Icons.sync_rounded, Palette.brandBlue),
      SyncState.pending => (Icons.cloud_upload_outlined, Palette.warning),
      SyncState.offline => (Icons.cloud_off_outlined, Palette.muted),
      SyncState.failed => (Icons.error_outline, Palette.danger),
      SyncState.signInRequired => (Icons.login_rounded, Palette.warning),
      SyncState.localOnly => (Icons.laptop_chromebook_outlined, Palette.muted),
    };
    if (compact) {
      return IconButton(
          tooltip: 'Sync: ${st.label}',
          onPressed: () => showSyncDetails(context, ref),
          icon: Icon(icon, color: color));
    }
    return Tooltip(
      message: 'Sync status',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => showSyncDetails(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Pill(st.label, color: color, icon: icon),
        ),
      ),
    );
  }
}

Future<void> showSyncDetails(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (c) => Consumer(builder: (c, ref, _) {
      final st = ref.watch(syncStatusProvider).value ?? const SyncStatus(SyncState.localOnly);
      final sync = ref.read(syncProvider);
      final signedIn = ref.read(remoteProvider).signedIn;
      return AlertDialog(
        title: const Text('Sync status'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(st.label, style: Theme.of(c).textTheme.titleMedium),
              const SizedBox(height: 10),
              Text('Pending changes: ${st.pending}'),
              Text('Failed operations: ${st.failed}'),
              Text('Conflicts to resolve: ${st.conflicts}'),
              Text('Last successful sync: ${st.lastSync == null ? 'never' : fmtDateTime(st.lastSync!)}'),
              if (st.lastError != null) ...[
                const SizedBox(height: 8),
                Text('Last error: ${st.lastError}', style: const TextStyle(color: Palette.danger)),
              ],
              const SizedBox(height: 10),
              Text(
                  signedIn
                      ? 'Your data is saved on this device first and uploaded when possible.'
                      : firebaseConfigured
                          ? 'Sign in under Settings → Account to back up to the cloud. Everything works offline without it.'
                          : 'Cloud sync is not configured in this build. Everything is stored safely on this device.',
                  style: const TextStyle(color: Palette.muted)),
            ]),
          ),
        ),
        actions: [
          if (st.failed > 0) TextButton(onPressed: sync.retryFailed, child: const Text('Retry failed')),
          if (signedIn) FilledButton(onPressed: sync.syncNow, child: const Text('Sync now')),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
        ],
      );
    }),
  );
}
