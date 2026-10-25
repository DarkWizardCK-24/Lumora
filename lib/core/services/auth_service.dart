import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' show AesGcm, SecretBox, SecretBoxAuthenticationError, SecretKey;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app_database.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Too many wrong attempts; try again after [remaining].
class LockedException extends AuthException {
  LockedException(this.remaining) : super('Too many attempts. Try again in ${formatWait(remaining)}.');
  final Duration remaining;
}

String formatWait(Duration d) {
  final s = d.inSeconds + (d.inMilliseconds % 1000 > 0 ? 1 : 0);
  return s >= 60 ? '${(s / 60).ceil()} min' : '${s}s';
}

class LocalUser {
  const LocalUser(
      {required this.id, required this.name, required this.email, required this.dbFile, this.avatar});
  final String id, name, email, dbFile;
  final Uint8List? avatar;

  LocalUser withAvatar(Uint8List? a) =>
      LocalUser(id: id, name: name, email: email, dbFile: dbFile, avatar: a);
}

/// A successful authentication: the account plus its data-encryption key.
/// [recoveryKey] is set only when a new one was just issued and must be shown once.
class AuthResult {
  const AuthResult(this.user, this.key, {this.recoveryKey});
  final LocalUser user;
  final Uint8List key;
  final String? recoveryKey;
}

const _defaultIterations = 60000;
const _keyLength = 32;
const maxFreeAttempts = 5;
const _baseLock = Duration(seconds: 30);
const _maxLock = Duration(minutes: 15);
const _fileMagic = [0x4c, 0x4d, 0x52, 0x31]; // "LMR1"
const _recoveryAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// PBKDF2-HMAC-SHA256. Pure Dart; run it off the UI isolate.
List<int> pbkdf2(String password, List<int> salt, {int iterations = _defaultIterations}) {
  final hmac = Hmac(sha256, utf8.encode(password));
  final block = Uint8List.fromList([...salt, 0, 0, 0, 1]);
  var u = hmac.convert(block).bytes;
  final out = List<int>.from(u);
  for (var i = 1; i < iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < out.length; j++) {
      out[j] ^= u[j];
    }
  }
  return out.sublist(0, _keyLength);
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var r = 0;
  for (var i = 0; i < a.length; i++) {
    r |= a[i] ^ b[i];
  }
  return r == 0;
}

Uint8List _randomBytes(int n) => Uint8List.fromList(List.generate(n, (_) => Random.secure().nextInt(256)));

String _newRecoveryKey() {
  final raw = List.generate(24, (_) => _recoveryAlphabet[Random.secure().nextInt(_recoveryAlphabet.length)]);
  return [for (var i = 0; i < raw.length; i += 4) raw.sublist(i, i + 4).join()].join('-');
}

String normalizeRecoveryKey(String k) => k.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

class _BadKey implements Exception {}

/// Offline accounts in a dedicated SQLite file (`lumora_accounts.db`).
///
/// * Every account owns its own data database, so users never see each other's records.
/// * Passwords are never stored. A random 256-bit data key encrypts the account's
///   database file at rest (AES-256-GCM); that key is stored wrapped twice — once by a
///   key derived from the password and once by one derived from the recovery key.
/// * Repeated wrong passwords lock the account with an escalating delay.
class AuthService {
  AuthService._(this._db, this.dataDir, this._iterations, this._now);
  final Database _db;
  final String dataDir;
  final int _iterations;
  final DateTime Function() _now;
  final _aes = AesGcm.with256bits();

  static Future<AuthService> open(
      {String? path, String? dataDir, int iterations = _defaultIterations, DateTime Function()? now}) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dir = dataDir ?? (await getApplicationSupportDirectory()).path;
    final db = await openDatabase(
      path ?? p.join(dir, 'lumora_accounts.db'),
      version: 2,
      onCreate: (d, v) async {
        await d.execute('''CREATE TABLE users(
          id TEXT PRIMARY KEY, name TEXT NOT NULL, email TEXT NOT NULL UNIQUE,
          salt TEXT NOT NULL, hash TEXT NOT NULL, iterations INTEGER NOT NULL,
          db_file TEXT NOT NULL, created_at INTEGER NOT NULL,
          failed_attempts INTEGER NOT NULL DEFAULT 0, locked_until INTEGER NOT NULL DEFAULT 0,
          wrapped_pw TEXT, wrapped_rec TEXT, rec_salt TEXT, avatar BLOB)''');
        await d.execute('CREATE TABLE auth_state(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      },
      onUpgrade: (d, from, to) async {
        if (from < 2) {
          for (final c in [
            'failed_attempts INTEGER NOT NULL DEFAULT 0',
            'locked_until INTEGER NOT NULL DEFAULT 0',
            'wrapped_pw TEXT',
            'wrapped_rec TEXT',
            'rec_salt TEXT',
            'avatar BLOB',
          ]) {
            await d.execute('ALTER TABLE users ADD COLUMN $c');
          }
        }
      },
    );
    return AuthService._(db, dir, iterations, now ?? DateTime.now);
  }

  Future<void> close() => _db.close();

  /// Working (decrypted) path of an account's database while it is signed in.
  String dbPath(LocalUser u) => p.join(dataDir, u.dbFile);
  String _encPath(LocalUser u) => '${dbPath(u)}.enc';

  static String normalizeEmail(String e) => e.trim().toLowerCase();

  static String? validateEmail(String e) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e.trim()) ? null : 'Enter a valid email address';

  static String? validatePassword(String pw) => pw.length < 6 ? 'Use at least 6 characters' : null;

  LocalUser _fromRow(Map<String, Object?> r) => LocalUser(
      id: r['id'] as String,
      name: r['name'] as String,
      email: r['email'] as String,
      dbFile: r['db_file'] as String,
      avatar: r['avatar'] as Uint8List?);

  Future<bool> hasUsers() async => (await _db.query('users', limit: 1)).isNotEmpty;

  /// Accounts on this device, for the account chooser.
  Future<List<LocalUser>> accounts() async =>
      (await _db.query('users', orderBy: 'created_at')).map(_fromRow).toList();

  Future<String?> lastEmail() => _getState('last_email');

  Future<Map<String, Object?>?> _row(String email) async {
    final rows = await _db.query('users', where: 'email = ?', whereArgs: [normalizeEmail(email)]);
    return rows.isEmpty ? null : rows.first;
  }

  // ── key wrapping ────────────────────────────────────────────────────────

  Future<String> _wrap(Uint8List key, List<int> kek) async {
    final box = await _aes.encrypt(key, secretKey: SecretKey(kek));
    return base64.encode(box.concatenation());
  }

  Future<Uint8List> _unwrap(String wrapped, List<int> kek) async {
    try {
      final box = SecretBox.fromConcatenation(base64.decode(wrapped), nonceLength: 12, macLength: 16);
      return Uint8List.fromList(await _aes.decrypt(box, secretKey: SecretKey(kek)));
    } on SecretBoxAuthenticationError {
      throw _BadKey();
    }
  }

  Future<List<int>> _derive(String secret, List<int> salt, int iterations) =>
      Isolate.run(() => pbkdf2(secret, salt, iterations: iterations));

  // ── lockout ─────────────────────────────────────────────────────────────

  Future<void> _checkLock(Map<String, Object?> row) async {
    final left = (row['locked_until'] as int) - _now().millisecondsSinceEpoch;
    if (left > 0) throw LockedException(Duration(milliseconds: left));
  }

  /// Records a failed attempt and returns the error to throw.
  Future<AuthException> _fail(Map<String, Object?> row, String message) async {
    final n = (row['failed_attempts'] as int) + 1;
    var lockedUntil = 0;
    if (n >= maxFreeAttempts) {
      final ms = min(_baseLock.inMilliseconds * pow(2, n - maxFreeAttempts).toInt(), _maxLock.inMilliseconds);
      lockedUntil = _now().millisecondsSinceEpoch + ms;
    }
    await _db.update('users', {'failed_attempts': n, 'locked_until': lockedUntil},
        where: 'id = ?', whereArgs: [row['id']]);
    if (lockedUntil > 0) return LockedException(Duration(milliseconds: lockedUntil - _now().millisecondsSinceEpoch));
    final left = maxFreeAttempts - n;
    return AuthException('$message ($left ${left == 1 ? 'attempt' : 'attempts'} left before a temporary lock)');
  }

  Future<void> _clearFailures(Object? id) =>
      _db.update('users', {'failed_attempts': 0, 'locked_until': 0}, where: 'id = ?', whereArgs: [id]);

  // ── sign up / in / recovery ─────────────────────────────────────────────

  Future<AuthResult> signUp({required String name, required String email, required String password}) async {
    final mail = normalizeEmail(email);
    final err = validateEmail(mail) ?? validatePassword(password);
    if (err != null) throw AuthException(err);
    if (await _row(mail) != null) throw AuthException('An account with this email already exists');
    final id = newId();
    final key = _randomBytes(32);
    final salt = _randomBytes(16);
    final wrappedPw = await _wrap(key, await _derive(password, salt, _iterations));
    final recovery = _newRecoveryKey();
    final recSalt = _randomBytes(16);
    final wrappedRec = await _wrap(key, await _derive(normalizeRecoveryKey(recovery), recSalt, _iterations));
    // The first account on an existing install adopts the pre-login database.
    final adopt = !await hasUsers() && await File(p.join(dataDir, 'lumora.db')).exists();
    final row = <String, Object?>{
      'id': id,
      'name': name.trim().isEmpty ? mail.split('@').first : name.trim(),
      'email': mail,
      'salt': base64.encode(salt),
      'hash': '',
      'iterations': _iterations,
      'db_file': adopt ? 'lumora.db' : 'lumora_$id.db',
      'created_at': _now().millisecondsSinceEpoch,
      'wrapped_pw': wrappedPw,
      'wrapped_rec': wrappedRec,
      'rec_salt': base64.encode(recSalt),
    };
    await _db.insert('users', row);
    await _setState('last_email', mail);
    return AuthResult(_fromRow(row), key, recoveryKey: recovery);
  }

  Future<AuthResult> signIn({required String email, required String password}) async {
    const bad = 'Incorrect email or password';
    final row = await _row(email);
    if (row == null) throw AuthException(bad);
    await _checkLock(row);
    final derived = await _derive(password, base64.decode(row['salt'] as String), row['iterations'] as int);
    Uint8List key;
    String? recovery;
    final wrapped = row['wrapped_pw'] as String?;
    if (wrapped != null) {
      try {
        key = await _unwrap(wrapped, derived);
      } on _BadKey {
        throw await _fail(row, bad);
      }
    } else {
      // Account created before encryption existed: verify the old hash, then upgrade it.
      if (!_constantTimeEquals(base64.decode(row['hash'] as String), derived)) throw await _fail(row, bad);
      key = _randomBytes(32);
      final recSalt = _randomBytes(16);
      recovery = _newRecoveryKey();
      await _db.update(
          'users',
          {
            'hash': '',
            'wrapped_pw': await _wrap(key, derived),
            'wrapped_rec': await _wrap(key, await _derive(normalizeRecoveryKey(recovery), recSalt, _iterations)),
            'rec_salt': base64.encode(recSalt),
          },
          where: 'id = ?',
          whereArgs: [row['id']]);
    }
    await _clearFailures(row['id']);
    await _setState('last_email', normalizeEmail(email));
    return AuthResult(_fromRow(row), key, recoveryKey: recovery);
  }

  /// Sets a new password using the recovery key. The data stays readable because
  /// only the key wrapping changes. Issues a fresh recovery key.
  Future<AuthResult> resetPassword(
      {required String email, required String recoveryKey, required String newPassword}) async {
    final err = validatePassword(newPassword);
    if (err != null) throw AuthException(err);
    final row = await _row(email);
    if (row == null) throw AuthException('Email or recovery key is incorrect');
    final wrappedRec = row['wrapped_rec'] as String?;
    if (wrappedRec == null) throw AuthException('This account has no recovery key. Sign in with your password first.');
    await _checkLock(row);
    final recDerived = await _derive(
        normalizeRecoveryKey(recoveryKey), base64.decode(row['rec_salt'] as String), row['iterations'] as int);
    Uint8List key;
    try {
      key = await _unwrap(wrappedRec, recDerived);
    } on _BadKey {
      throw await _fail(row, 'Email or recovery key is incorrect');
    }
    final salt = _randomBytes(16);
    final recSalt = _randomBytes(16);
    final recovery = _newRecoveryKey();
    await _db.update(
        'users',
        {
          'salt': base64.encode(salt),
          'iterations': _iterations,
          'hash': '',
          'wrapped_pw': await _wrap(key, await _derive(newPassword, salt, _iterations)),
          'wrapped_rec': await _wrap(key, await _derive(normalizeRecoveryKey(recovery), recSalt, _iterations)),
          'rec_salt': base64.encode(recSalt),
          'failed_attempts': 0,
          'locked_until': 0,
        },
        where: 'id = ?',
        whereArgs: [row['id']]);
    await _setState('last_email', normalizeEmail(email));
    final fresh = (await _row(email))!;
    return AuthResult(_fromRow(fresh), key, recoveryKey: recovery);
  }

  Future<void> changePassword(LocalUser u, String oldPassword, String newPassword) async {
    final err = validatePassword(newPassword);
    if (err != null) throw AuthException(err);
    final r = await _verified(u, oldPassword, 'Current password is incorrect');
    final salt = _randomBytes(16);
    await _db.update(
        'users',
        {
          'salt': base64.encode(salt),
          'iterations': _iterations,
          'hash': '',
          'wrapped_pw': await _wrap(r.key, await _derive(newPassword, salt, _iterations)),
        },
        where: 'id = ?',
        whereArgs: [u.id]);
  }

  /// Issues a new recovery key (invalidating the old one). Needs the password.
  Future<String> regenerateRecoveryKey(LocalUser u, String password) async {
    final r = await _verified(u, password, 'Password is incorrect');
    final recSalt = _randomBytes(16);
    final recovery = _newRecoveryKey();
    await _db.update(
        'users',
        {
          'wrapped_rec': await _wrap(r.key, await _derive(normalizeRecoveryKey(recovery), recSalt, _iterations)),
          'rec_salt': base64.encode(recSalt),
        },
        where: 'id = ?',
        whereArgs: [u.id]);
    return recovery;
  }

  /// Removes the account and its data files. [beforeDelete] runs after the
  /// password check so the caller can close the open data database.
  Future<void> deleteAccount(LocalUser u, String password, {Future<void> Function()? beforeDelete}) async {
    await _verified(u, password, 'Password is incorrect');
    await beforeDelete?.call();
    await _db.delete('users', where: 'id = ?', whereArgs: [u.id]);
    for (final base in [dbPath(u), _encPath(u)]) {
      for (final suffix in ['', '-wal', '-shm', '-journal', '.tmp']) {
        final f = File('$base$suffix');
        if (await f.exists()) await f.delete();
      }
    }
  }

  Future<AuthResult> _verified(LocalUser u, String password, String message) async {
    try {
      return await signIn(email: u.email, password: password);
    } on LockedException {
      rethrow;
    } on AuthException {
      throw AuthException(message);
    }
  }

  Future<void> setAvatar(LocalUser u, Uint8List? bytes) =>
      _db.update('users', {'avatar': bytes}, where: 'id = ?', whereArgs: [u.id]);

  // ── encrypted data file ─────────────────────────────────────────────────

  /// Decrypts the account's database to its working path and returns it.
  /// A plaintext file newer than the encrypted copy (left by a crash) is kept.
  Future<String> openData(LocalUser u, Uint8List key) async {
    final plain = File(dbPath(u));
    final enc = File(_encPath(u));
    if (await enc.exists()) {
      final leftover = await plain.exists() && (await plain.lastModified()).isAfter(await enc.lastModified());
      if (!leftover) {
        final bytes = await enc.readAsBytes();
        if (bytes.length < _fileMagic.length + 28 || !listEquals(bytes.sublist(0, 4), _fileMagic)) {
          throw AuthException('Your data file is not a valid Lumora file.');
        }
        try {
          final box = SecretBox.fromConcatenation(bytes.sublist(4), nonceLength: 12, macLength: 16);
          await plain.writeAsBytes(await _aes.decrypt(box, secretKey: SecretKey(key)), flush: true);
        } on SecretBoxAuthenticationError {
          throw AuthException('Could not decrypt your data. The file may be damaged.');
        }
      }
    }
    return plain.path;
  }

  /// Encrypts the working database (which must be closed) and removes the plaintext.
  Future<void> sealData(LocalUser u, Uint8List key) async {
    final plain = File(dbPath(u));
    if (!await plain.exists()) return;
    final box = await _aes.encrypt(await plain.readAsBytes(), secretKey: SecretKey(key));
    final tmp = File('${_encPath(u)}.tmp');
    await tmp.writeAsBytes([..._fileMagic, ...box.concatenation()], flush: true);
    await tmp.rename(_encPath(u));
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final f = File('${plain.path}$suffix');
      if (await f.exists()) await f.delete();
    }
  }

  Future<void> _setState(String k, String v) =>
      _db.insert('auth_state', {'key': k, 'value': v}, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<String?> _getState(String k) async {
    final r = await _db.query('auth_state', where: 'key = ?', whereArgs: [k]);
    return r.isEmpty ? null : r.first['value'] as String;
  }
}
