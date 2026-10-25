import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';

/// The signed-in local account and the actions on it. Overridden by the auth
/// root; null when the app runs without a login gate (tests, developer env vars).
class SessionController {
  SessionController({
    required this.user,
    required this.signOut,
    required this.changePassword,
    required this.deleteAccount,
    required this.setAvatar,
    required this.newRecoveryKey,
  });
  final LocalUser user;
  final Future<void> Function() signOut;
  final Future<void> Function(String oldPassword, String newPassword) changePassword;
  final Future<void> Function(String password) deleteAccount;
  final Future<void> Function(Uint8List? png) setAvatar;

  /// Issues a replacement recovery key (needs the password) and returns it.
  final Future<String> Function(String password) newRecoveryKey;
}

final sessionProvider = Provider<SessionController?>((ref) => null);
