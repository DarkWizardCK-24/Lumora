import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lumora/core/providers/app_providers.dart';
import 'package:lumora/core/providers/settings_provider.dart';
import 'package:lumora/core/providers/sync_provider.dart';
import 'package:lumora/core/services/app_database.dart';
import 'package:lumora/core/services/demo_data.dart';
import 'package:lumora/core/services/repository.dart';
import 'package:lumora/ui/app.dart';
import 'package:lumora/ui/routes/app_router.dart';

const _routes = [
  '/', '/goals', '/subjects', '/sessions', '/coding', '/notes', '/calendar',
  '/milestones', '/analysis', '/analytics', '/review', '/settings', '/more',
  '/flashcards', '/insights', '/focus',
];

// Logical widths from the spec: phones, tablets, small and large desktops.
const _sizes = <(double, double)>[
  (320, 640), (360, 780), (390, 844), (430, 932), (600, 900), (768, 1024), (1024, 768), (1366, 768), (1920, 1080),
];

void main() {
  late AppDatabase db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> pumpApp(WidgetTester tester, {required bool seeded, double textScale = 1}) async {
    await tester.runAsync(() async {
      db = await AppDatabase.open(path: inMemoryDatabasePath);
      if (seeded) await seedDemoData(Repository(db));
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        connectivityBinder.overrideWith((ref) {}), // platform plugin is unavailable in unit tests
        initialSettingsProvider.overrideWithValue(const AppSettings()),
      ],
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const LumoraApp(),
      ),
    ));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final seeded in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('no layout overflow — ${seeded ? 'with data' : 'empty'} @ ${scale}x text', (tester) async {
        addTearDown(tester.view.reset);
        await pumpApp(tester, seeded: seeded, textScale: scale);
        final failures = <String>{};
        for (final (w, h) in _sizes) {
          tester.view
            ..devicePixelRatio = 1
            ..physicalSize = Size(w, h);
          for (final r in _routes) {
            appRouter.go(r);
            await settle(tester);
            final e = tester.takeException();
            if (e != null) {
              final first = e.toString().split(String.fromCharCode(10)).first;
              failures.add('$r @ ${w.toInt()}x${h.toInt()}: ${first.length > 110 ? first.substring(0, 110) : first}');
            }
          }
        }
        await tester.runAsync(() => db.close());
        expect(failures, isEmpty, reason: failures.join(String.fromCharCode(10)));
      });
    }
  }
}
