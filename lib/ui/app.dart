import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/colors/theme_palettes.dart';
import '../core/providers/settings_provider.dart';
import '../core/theme/app_theme.dart';
import 'routes/app_router.dart';

class LumoraApp extends ConsumerWidget {
  const LumoraApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final seed = ref.watch(settingsProvider.select((s) => seedFor(s.paletteId, s.accentColor)));
    final amoled = ref.watch(settingsProvider.select((s) => s.amoled));
    final fontScale = ref.watch(settingsProvider.select((s) => s.fontScale));
    return MaterialApp.router(
      title: 'Lumora',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light, seed: seed),
      darkTheme: buildTheme(Brightness.dark, seed: seed, amoled: amoled),
      themeMode: mode,
      routerConfig: appRouter,
      builder: (context, child) {
        // Our font-size preference multiplies the system one instead of replacing it.
        final mq = MediaQuery.of(context);
        final system = mq.textScaler.scale(100) / 100;
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(system * fontScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
