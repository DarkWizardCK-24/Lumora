import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_providers.dart';
import 'settings_provider.dart';
import '../services/firebase_rest_store.dart';
import '../services/remote_store.dart';
import '../services/sync_service.dart';

final remoteProvider = Provider<RemoteStore>((ref) => FirebaseRestStore(ref.watch(dbProvider)));

final syncProvider = Provider<SyncService>((ref) {
  return SyncService(ref.watch(dbProvider), ref.watch(remoteProvider));
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  final sync = ref.watch(syncProvider);
  await sync.refreshStatus();
  yield sync.last;
  yield* sync.statusStream;
});

/// Connectivity is only a hint; failures are still handled by the sync engine.
final connectivityBinder = Provider<void>((ref) {
  final sync = ref.watch(syncProvider);
  final settings = ref.watch(settingsProvider);
  sync.enabled = settings.syncEnabled;
  final sub = Connectivity().onConnectivityChanged.listen((r) {
    sync.online = !r.contains(ConnectivityResult.none);
    if (sync.online) sync.syncNow();
    sync.refreshStatus();
  });
  Timer? timer = Timer.periodic(const Duration(minutes: 2), (_) => sync.syncNow());
  ref.onDispose(() {
    sub.cancel();
    timer?.cancel();
    timer = null;
  });
});
