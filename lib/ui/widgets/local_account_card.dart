import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/colors/app_colors.dart';
import '../../core/providers/session_provider.dart';
import '../../core/services/auth_service.dart';
import '../utils/app_snack.dart';
import 'confirmation_dialog.dart';
import 'form_dialog.dart';
import 'recovery_key_dialog.dart';
import 'section_card.dart';
import 'user_avatar.dart';

/// The signed-in offline account: picture, switch/sign out, password, recovery key, delete.
/// Hidden when the app runs without a login gate.
class LocalAccountCard extends ConsumerWidget {
  const LocalAccountCard({super.key});

  Future<void> _pickPicture(BuildContext context, SessionController s) async {
    final picked = await FilePicker.pickFiles(type: FileType.image);
    final path = picked.isEmpty ? null : picked.first.path;
    if (path == null) return;
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 256);
      final image = (await codec.getNextFrame()).image;
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      await s.setAvatar(png);
    } catch (_) {
      if (context.mounted) toast(context, 'Could not read that image', error: true);
    }
  }

  Future<void> _changePassword(BuildContext context, SessionController s) async {
    final v = await showForm(context, title: 'Change password', submitLabel: 'Change', fields: const [
      FText('old', 'Current password', required: true, obscure: true),
      FText('new', 'New password (6+ characters)', required: true, obscure: true),
    ]);
    if (v == null) return;
    try {
      await s.changePassword(v['old'] as String, v['new'] as String);
      if (context.mounted) toast(context, 'Password changed');
    } on AuthException catch (e) {
      if (context.mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _newRecoveryKey(BuildContext context, SessionController s) async {
    final ok = await confirm(context, 'Create a new recovery key?',
        'Your current recovery key will stop working. The new one is shown once.',
        action: 'Continue', destructive: false);
    if (!ok || !context.mounted) return;
    final v = await showForm(context, title: 'Confirm with password', submitLabel: 'Create key', fields: const [
      FText('pw', 'Password', required: true, obscure: true),
    ]);
    if (v == null) return;
    try {
      final key = await s.newRecoveryKey(v['pw'] as String);
      if (context.mounted) await showRecoveryKey(context, key, reset: true);
    } on AuthException catch (e) {
      if (context.mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _delete(BuildContext context, SessionController s) async {
    final ok = await confirm(context, 'Delete this account?',
        'This permanently deletes the account and ALL of its goals, sessions and notes from this device. This cannot be undone.',
        action: 'Continue');
    if (!ok || !context.mounted) return;
    final v = await showForm(context, title: 'Confirm with password', submitLabel: 'Delete account', fields: const [
      FText('pw', 'Password', required: true, obscure: true),
    ]);
    if (v == null) return;
    try {
      await s.deleteAccount(v['pw'] as String);
    } on AuthException catch (e) {
      if (context.mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    if (s == null) return const SizedBox.shrink();
    return SectionCard(
      title: 'Local account',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: UserAvatar(s.user, radius: 26),
          title: Text(s.user.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(s.user.email),
        ),
        Wrap(spacing: 8, children: [
          TextButton.icon(
              onPressed: () => _pickPicture(context, s),
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(s.user.avatar == null ? 'Add picture' : 'Change picture')),
          if (s.user.avatar != null) TextButton(onPressed: () => s.setAvatar(null), child: const Text('Remove picture')),
        ]),
        const SizedBox(height: 4),
        const Text(
            'Your data is encrypted on this device and kept separate from other accounts. It is decrypted only while you are signed in.',
            style: TextStyle(color: Palette.muted)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
              onPressed: s.signOut,
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Switch account / sign out')),
          OutlinedButton(onPressed: () => _changePassword(context, s), child: const Text('Change password')),
          OutlinedButton(onPressed: () => _newRecoveryKey(context, s), child: const Text('New recovery key')),
          OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Palette.danger),
              onPressed: () => _delete(context, s),
              child: const Text('Delete account')),
        ]),
      ]),
    );
  }
}
