import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';

import 'core/providers/app_providers.dart';
import 'core/providers/settings_provider.dart';
import 'core/services/app_database.dart';
import 'core/services/auth_service.dart';
import 'core/services/demo_data.dart';
import 'core/services/repository.dart';
import 'ui/app.dart';
import 'ui/auth_root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;
  Logger.root.onRecord.listen((r) => debugPrint('[${r.level.name}] ${r.loggerName}: ${r.message}'));
  FlutterError.onError = (d) {
    Logger('flutter').severe(d.exceptionAsString(), d.exception, d.stack);
    FlutterError.presentError(d);
  };

  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();
    const size = Size(1366, 820);
    // LUMORA_WINDOW=WxH lets the screenshot script open the app at any size.
    final env = Platform.environment['LUMORA_WINDOW']?.split('x');
    final w = env != null && env.length == 2 ? Size(double.parse(env[0]), double.parse(env[1])) : size;
    await windowManager.waitUntilReadyToShow(
      WindowOptions(size: w, minimumSize: const Size(320, 480), center: true, title: 'Lumora'),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  // Developer shortcuts (screenshots, demos) open a database directly, without a login.
  final devDb = Platform.environment['LUMORA_DB'];
  final devSeed = Platform.environment['LUMORA_SEED_DEMO'] == '1';
  if (devDb != null || devSeed) {
    final db = await AppDatabase.open(path: devDb);
    if (devSeed) await seedDemoData(Repository(db)); // developer-only, for README screenshots
    final settings = await AppSettings.load(db);
    runApp(ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        initialSettingsProvider.overrideWithValue(settings),
      ],
      child: const LumoraApp(),
    ));
    return;
  }

  final auth = await AuthService.open();
  runApp(AuthRoot(auth: auth));
}
