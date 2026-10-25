import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';

import '../core/colors/theme_palettes.dart';
import '../core/providers/app_providers.dart';
import '../core/providers/session_provider.dart';
import '../core/providers/settings_provider.dart';
import '../core/services/app_database.dart';
import '../core/services/auth_service.dart';
import '../core/services/roadmap_python_mastery.dart';
import '../core/theme/app_theme.dart';
import 'app.dart';
import 'routes/app_router.dart';
import 'screens/auth_screen.dart';

/// Gate in front of the app: shows the account screen until someone signs in,
/// then decrypts that account's database, opens it and starts [LumoraApp].
/// Signing out (or closing the window) closes the database and encrypts it again.
class AuthRoot extends StatefulWidget {
  const AuthRoot({super.key, required this.auth});
  final AuthService auth;

  @override
  State<AuthRoot> createState() => _AuthRootState();
}

class _Session {
  _Session(this.user, this.key, this.db, this.settings);
  LocalUser user;
  final Uint8List key;
  final AppDatabase db;
  final AppSettings settings;
}

class _AuthRootState extends State<AuthRoot> with WindowListener {
  _Session? _session;
  bool _starting = false;
  String? _startError;

  static bool get _desktop => !kIsWeb && Platform.isWindows;

  @override
  void initState() {
    super.initState();
    if (_desktop) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
    }
  }

  @override
  void dispose() {
    if (_desktop) windowManager.removeListener(this);
    super.dispose();
  }

  /// Seal the database before the window goes away so no plaintext is left behind.
  @override
  Future<void> onWindowClose() async {
    try {
      await _seal();
    } finally {
      await windowManager.destroy();
    }
  }

  Future<void> _seal() async {
    final s = _session;
    if (s == null) return;
    _session = null;
    await s.db.close();
    await widget.auth.sealData(s.user, s.key);
  }

  Future<void> _start(AuthResult r) async {
    setState(() {
      _starting = true;
      _startError = null;
    });
    try {
      final path = await widget.auth.openData(r.user, r.key);
      final db = await AppDatabase.open(path: path);
      try {
        await addPythonRoadmapOnce(db);
      } catch (e, st) {
        Logger('roadmap').severe('Could not add the Python roadmap', e, st);
      }
      var settings = await AppSettings.load(db);
      if (settings.profileName.isEmpty) settings = settings.copyWith(profileName: r.user.name);
      appRouter.go('/');
      if (mounted) setState(() => _session = _Session(r.user, r.key, db, settings));
    } on AuthException catch (e) {
      if (mounted) setState(() => _startError = e.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _end() async {
    await _seal();
    if (mounted) setState(() {});
  }

  Future<void> _delete(String password) async {
    final s = _session!;
    // Verified first by the service, so a wrong password leaves the app open.
    await widget.auth.deleteAccount(s.user, password, beforeDelete: () async {
      _session = null;
      await s.db.close();
      if (mounted) setState(() {});
    });
  }

  Future<void> _setAvatar(Uint8List? png) async {
    final s = _session!;
    await widget.auth.setAvatar(s.user, png);
    if (mounted) setState(() => s.user = s.user.withAvatar(png));
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    if (s != null) {
      return ProviderScope(
        key: ValueKey(s.user.id),
        overrides: [
          dbProvider.overrideWithValue(s.db),
          initialSettingsProvider.overrideWithValue(s.settings),
          sessionProvider.overrideWithValue(SessionController(
            user: s.user,
            signOut: _end,
            changePassword: (o, n) => widget.auth.changePassword(s.user, o, n),
            deleteAccount: _delete,
            setAvatar: _setAvatar,
            newRecoveryKey: (pw) => widget.auth.regenerateRecoveryKey(s.user, pw),
          )),
        ],
        child: const LumoraApp(),
      );
    }
    return MaterialApp(
      title: 'Lumora',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light, seed: seedFor('ocean', 0)),
      home: _starting
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : Stack(children: [
              AuthScreen(auth: widget.auth, onAuthenticated: _start),
              if (_startError != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Material(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_startError!, style: const TextStyle(color: Colors.white))),
                  ),
                ),
            ]),
    );
  }
}
