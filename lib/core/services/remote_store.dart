import 'dart:async';

/// Compile-time Firebase web config: pass with
/// `--dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_PROJECT_ID=...`.
/// These are public identifiers, never admin credentials.
const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');

const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

bool get firebaseConfigured => firebaseApiKey.isNotEmpty && firebaseProjectId.isNotEmpty;

class SyncException implements Exception {
  SyncException(this.message, {this.transient = true});
  final String message;
  final bool transient;
  @override
  String toString() => message;
}

class RemoteDoc {
  RemoteDoc(this.type, this.id, this.data, {this.deleted = false});
  final String type, id;
  final Map<String, Object?> data;
  final bool deleted;
}

/// Cloud boundary. The sync engine only talks to this interface so it can be
/// tested with a fake and swapped for a native SDK on platforms that have one.
abstract class RemoteStore {
  bool get signedIn;
  String? get email;
  Future<void> signUp(String email, String password);
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<void> restore();
  Future<void> put(String type, String id, Map<String, Object?> data);
  Future<void> remove(String type, String id, int deletedAt);
  Future<List<RemoteDoc>> pullSince(int updatedAfter);
}
