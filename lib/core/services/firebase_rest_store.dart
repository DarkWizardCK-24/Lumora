import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_database.dart';
import 'remote_store.dart';

/// Firebase Auth + Firestore through their REST APIs (works on Windows where
/// the native Firestore SDK is unavailable).
class FirebaseRestStore implements RemoteStore {
  FirebaseRestStore(this.db, {http.Client? client}) : _http = client ?? http.Client();
  final AppDatabase db;
  final http.Client _http;
  String? _idToken, _refresh, _uid, _email;
  int _expiresAt = 0;

  @override
  bool get signedIn => _uid != null;
  @override
  String? get email => _email;

  Future<void> _store() async {
    await db.setMeta('auth.idToken', _idToken ?? '');
    await db.setMeta('auth.refresh', _refresh ?? '');
    await db.setMeta('auth.uid', _uid ?? '');
    await db.setMeta('auth.email', _email ?? '');
    await db.setMeta('auth.expires', '$_expiresAt');
  }

  @override
  Future<void> restore() async {
    final uid = await db.meta('auth.uid');
    if (uid == null || uid.isEmpty) return;
    _uid = uid;
    _idToken = await db.meta('auth.idToken');
    _refresh = await db.meta('auth.refresh');
    _email = await db.meta('auth.email');
    _expiresAt = int.tryParse(await db.meta('auth.expires') ?? '') ?? 0;
  }

  Future<void> _auth(String endpoint, String email, String password) async {
    if (!firebaseConfigured) {
      throw SyncException('Firebase is not configured for this build.', transient: false);
    }
    final res = await _http
        .post(
          Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:$endpoint?key=$firebaseApiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password, 'returnSecureToken': true}),
        )
        .timeout(const Duration(seconds: 20));
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw SyncException(_authMessage(j['error']?['message'] as String?), transient: false);
    }
    _idToken = j['idToken'] as String;
    _refresh = j['refreshToken'] as String;
    _uid = j['localId'] as String;
    _email = email;
    _expiresAt = DateTime.now().millisecondsSinceEpoch + int.parse(j['expiresIn'] as String) * 1000;
    await _store();
  }

  String _authMessage(String? code) => switch (code) {
        'EMAIL_EXISTS' => 'An account with this email already exists.',
        'INVALID_LOGIN_CREDENTIALS' || 'INVALID_PASSWORD' || 'EMAIL_NOT_FOUND' =>
          'Incorrect email or password.',
        final c? when c.startsWith('WEAK_PASSWORD') => 'Password must be at least 6 characters.',
        _ => 'Authentication failed (${code ?? 'unknown'}).',
      };

  @override
  Future<void> signUp(String email, String password) => _auth('signUp', email, password);
  @override
  Future<void> signIn(String email, String password) => _auth('signInWithPassword', email, password);

  @override
  Future<void> signOut() async {
    // Local data is intentionally untouched.
    _idToken = _refresh = _uid = _email = null;
    await _store();
  }

  Future<String> _token() async {
    if (_uid == null) throw SyncException('Sign-in required.', transient: false);
    if (DateTime.now().millisecondsSinceEpoch > _expiresAt - 60000) {
      final res = await _http.post(
        Uri.parse('https://securetoken.googleapis.com/v1/token?key=$firebaseApiKey'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'grant_type': 'refresh_token', 'refresh_token': _refresh ?? ''},
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        throw SyncException('Session expired — please sign in again.', transient: false);
      }
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      _idToken = j['id_token'] as String;
      _refresh = j['refresh_token'] as String;
      _expiresAt = DateTime.now().millisecondsSinceEpoch + int.parse(j['expires_in'] as String) * 1000;
      await _store();
    }
    return _idToken!;
  }

  String get _base =>
      'https://firestore.googleapis.com/v1/projects/$firebaseProjectId/databases/(default)/documents';

  Map<String, dynamic> _enc(Object? v) {
    if (v == null) return {'nullValue': null};
    if (v is int) return {'integerValue': '$v'};
    if (v is double) return {'doubleValue': v};
    if (v is bool) return {'booleanValue': v};
    return {'stringValue': '$v'};
  }

  Object? _dec(Map<String, dynamic> v) {
    if (v.containsKey('integerValue')) return int.parse(v['integerValue'] as String);
    if (v.containsKey('doubleValue')) return (v['doubleValue'] as num).toDouble();
    if (v.containsKey('booleanValue')) return v['booleanValue'] as bool;
    if (v.containsKey('stringValue')) return v['stringValue'] as String;
    return null;
  }

  Future<http.Response> _send(Future<http.Response> Function(Map<String, String> h) f) async {
    final token = await _token();
    try {
      final res = await f({'Authorization': 'Bearer $token', 'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 25));
      if (res.statusCode == 401 || res.statusCode == 403) {
        throw SyncException('Cloud access denied (${res.statusCode}). Check security rules.',
            transient: false);
      }
      if (res.statusCode >= 500 || res.statusCode == 429) {
        throw SyncException('Cloud temporarily unavailable (${res.statusCode}).');
      }
      if (res.statusCode >= 400) {
        throw SyncException('Cloud rejected the request: ${res.body}', transient: false);
      }
      return res;
    } on TimeoutException {
      throw SyncException('Cloud request timed out.');
    } on http.ClientException catch (e) {
      throw SyncException('Network error: ${e.message}');
    }
  }

  @override
  Future<void> put(String type, String id, Map<String, Object?> data) async {
    final doc = '$_base/users/$_uid/$type/$id';
    final body = jsonEncode({'fields': {for (final e in data.entries) e.key: _enc(e.value)}});
    // PATCH with a full document is an idempotent upsert.
    await _send((h) => _http.patch(Uri.parse(doc), headers: h, body: body));
  }

  @override
  Future<void> remove(String type, String id, int deletedAt) async {
    await _send((h) => _http.delete(Uri.parse('$_base/users/$_uid/$type/$id'), headers: h));
    final tomb = jsonEncode({
      'fields': {'type': _enc(type), 'id': _enc(id), 'deleted_at': _enc(deletedAt)}
    });
    await _send((h) =>
        _http.patch(Uri.parse('$_base/users/$_uid/tombstones/${type}_$id'), headers: h, body: tomb));
  }

  @override
  Future<List<RemoteDoc>> pullSince(int updatedAfter) async {
    final out = <RemoteDoc>[];
    for (final type in syncedTables) {
      final res = await _send((h) => _http.post(
            Uri.parse('$_base/users/$_uid:runQuery'),
            headers: h,
            body: jsonEncode({
              'structuredQuery': {
                'from': [
                  {'collectionId': type}
                ],
                'where': {
                  'fieldFilter': {
                    'field': {'fieldPath': 'updated_at'},
                    'op': 'GREATER_THAN',
                    'value': {'integerValue': '$updatedAfter'}
                  }
                }
              }
            }),
          ));
      for (final r in jsonDecode(res.body) as List) {
        final doc = (r as Map)['document'] as Map<String, dynamic>?;
        if (doc == null) continue;
        final fields = (doc['fields'] as Map<String, dynamic>? ?? {});
        final data = {for (final e in fields.entries) e.key: _dec(e.value as Map<String, dynamic>)};
        out.add(RemoteDoc(type, (data['id'] ?? (doc['name'] as String).split('/').last) as String, data));
      }
    }
    final res = await _send((h) => _http.post(
          Uri.parse('$_base/users/$_uid:runQuery'),
          headers: h,
          body: jsonEncode({
            'structuredQuery': {
              'from': [
                {'collectionId': 'tombstones'}
              ],
              'where': {
                'fieldFilter': {
                  'field': {'fieldPath': 'deleted_at'},
                  'op': 'GREATER_THAN',
                  'value': {'integerValue': '$updatedAfter'}
                }
              }
            }
          }),
        ));
    for (final r in jsonDecode(res.body) as List) {
      final doc = (r as Map)['document'] as Map<String, dynamic>?;
      if (doc == null) continue;
      final f = doc['fields'] as Map<String, dynamic>;
      out.add(RemoteDoc(_dec(f['type'] as Map<String, dynamic>) as String,
          _dec(f['id'] as Map<String, dynamic>) as String, const {},
          deleted: true));
    }
    return out;
  }
}
