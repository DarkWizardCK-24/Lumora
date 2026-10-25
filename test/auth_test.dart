import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lumora/core/services/auth_service.dart';

void main() {
  late Directory dir;
  late AuthService auth;
  var clock = DateTime(2026, 1, 1);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    clock = DateTime(2026, 1, 1);
    dir = await Directory.systemTemp.createTemp('lumora_auth');
    auth = await AuthService.open(dataDir: dir.path, iterations: 50, now: () => clock);
  });

  tearDown(() async {
    await auth.close();
    await dir.delete(recursive: true);
  });

  Future<AuthResult> signUp([String email = 'a@b.co', String pw = 'secret1']) =>
      auth.signUp(name: 'Ada', email: email, password: pw);

  test('sign up then sign in with the right password only', () async {
    final r = await auth.signUp(name: 'Ada', email: 'Ada@Example.com ', password: 'secret1');
    expect(r.user.email, 'ada@example.com');
    expect(r.recoveryKey, isNotNull);
    final again = await auth.signIn(email: 'ADA@example.com', password: 'secret1');
    expect(again.user.id, r.user.id);
    expect(again.key, r.key);
    expect(again.recoveryKey, isNull);
    expect(() => auth.signIn(email: 'ada@example.com', password: 'wrong!!'), throwsA(isA<AuthException>()));
    expect(() => auth.signIn(email: 'nobody@example.com', password: 'secret1'), throwsA(isA<AuthException>()));
  });

  test('validation and duplicate email', () async {
    expect(() => auth.signUp(name: '', email: 'bad', password: 'secret1'), throwsA(isA<AuthException>()));
    expect(() => auth.signUp(name: '', email: 'a@b.co', password: '123'), throwsA(isA<AuthException>()));
    await signUp();
    expect(() => signUp('A@B.co', 'secret2'), throwsA(isA<AuthException>()));
  });

  test('lockout after 5 wrong passwords, escalating, cleared by success after expiry', () async {
    await signUp();
    for (var i = 0; i < 4; i++) {
      await expectLater(auth.signIn(email: 'a@b.co', password: 'bad'), throwsA(isNot(isA<LockedException>())));
    }
    await expectLater(auth.signIn(email: 'a@b.co', password: 'bad'), throwsA(isA<LockedException>()));
    // Even the right password is refused while locked.
    await expectLater(auth.signIn(email: 'a@b.co', password: 'secret1'), throwsA(isA<LockedException>()));
    clock = clock.add(const Duration(seconds: 31));
    // One more failure doubles the delay to 60s.
    Object? e;
    try {
      await auth.signIn(email: 'a@b.co', password: 'bad');
    } catch (err) {
      e = err;
    }
    expect(e, isA<LockedException>());
    expect((e as LockedException).remaining.inSeconds, inInclusiveRange(59, 60));
    clock = clock.add(const Duration(seconds: 61));
    await auth.signIn(email: 'a@b.co', password: 'secret1');
    // Counter reset: a fresh wrong attempt is a plain error again.
    await expectLater(auth.signIn(email: 'a@b.co', password: 'bad'), throwsA(isNot(isA<LockedException>())));
  });

  test('recovery key resets the password and keeps the data key', () async {
    final r = await signUp();
    final bad = 'AAAA-AAAA-AAAA-AAAA-AAAA-AAAA';
    await expectLater(
        auth.resetPassword(email: 'a@b.co', recoveryKey: bad, newPassword: 'newpass1'), throwsA(isA<AuthException>()));
    final reset = await auth.resetPassword(
        email: 'a@b.co', recoveryKey: r.recoveryKey!.toLowerCase(), newPassword: 'newpass1');
    expect(reset.key, r.key);
    expect(reset.recoveryKey, isNot(r.recoveryKey));
    await expectLater(auth.signIn(email: 'a@b.co', password: 'secret1'), throwsA(isA<AuthException>()));
    expect((await auth.signIn(email: 'a@b.co', password: 'newpass1')).key, r.key);
    // The old recovery key no longer works.
    await expectLater(
        auth.resetPassword(email: 'a@b.co', recoveryKey: r.recoveryKey!, newPassword: 'other123'),
        throwsA(isA<AuthException>()));
  });

  test('data file is encrypted at rest and round-trips', () async {
    final r = await signUp();
    final plain = File(auth.dbPath(r.user));
    await plain.writeAsString('SECRET-NOTES-CONTENT');
    await auth.sealData(r.user, r.key);
    expect(plain.existsSync(), isFalse);
    final enc = File('${plain.path}.enc');
    expect(String.fromCharCodes(await enc.readAsBytes()).contains('SECRET-NOTES'), isFalse);

    await auth.openData(r.user, r.key);
    expect(await plain.readAsString(), 'SECRET-NOTES-CONTENT');

    await auth.sealData(r.user, r.key);
    final other = await signUp('b@b.co', 'secret2');
    await expectLater(auth.openData(r.user, other.key), throwsA(isA<AuthException>()));
  });

  test('password and recovery key are not stored in plain text', () async {
    final r = await signUp();
    final raw = String.fromCharCodes(await File('${dir.path}/lumora_accounts.db').readAsBytes());
    expect(raw.contains('secret1'), isFalse);
    expect(raw.contains(r.recoveryKey!), isFalse);
  });

  test('accounts list, separate data files, avatar, legacy adoption', () async {
    await File('${dir.path}/lumora.db').writeAsString('x');
    final a = await signUp('a@b.co');
    final b = await signUp('b@b.co', 'secret2');
    expect(a.user.dbFile, 'lumora.db');
    expect(b.user.dbFile, isNot('lumora.db'));
    await auth.setAvatar(a.user, Uint8List.fromList([1, 2, 3]));
    final list = await auth.accounts();
    expect(list.map((u) => u.email), ['a@b.co', 'b@b.co']);
    expect(list.first.avatar, [1, 2, 3]);
    expect(await auth.lastEmail(), 'b@b.co');
  });

  test('change password, new recovery key and delete account', () async {
    final r = await signUp();
    expect(() => auth.changePassword(r.user, 'nope', 'secret9'), throwsA(isA<AuthException>()));
    await auth.changePassword(r.user, 'secret1', 'secret9');
    await expectLater(auth.signIn(email: 'a@b.co', password: 'secret1'), throwsA(isA<AuthException>()));
    expect((await auth.signIn(email: 'a@b.co', password: 'secret9')).key, r.key);

    final fresh = await auth.regenerateRecoveryKey(r.user, 'secret9');
    expect(fresh, isNot(r.recoveryKey));
    await auth.resetPassword(email: 'a@b.co', recoveryKey: fresh, newPassword: 'secret9');

    await File(auth.dbPath(r.user)).writeAsString('data');
    await auth.sealData(r.user, r.key);
    await expectLater(auth.deleteAccount(r.user, 'bad'), throwsA(isA<AuthException>()));
    await auth.deleteAccount(r.user, 'secret9');
    expect(File('${auth.dbPath(r.user)}.enc').existsSync(), isFalse);
    expect(await auth.hasUsers(), isFalse);
  });
}
