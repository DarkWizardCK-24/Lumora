import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_providers.dart';
import '../services/app_database.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.dailyTargetMinutes = 60,
    this.weekStart = DateTime.monday,
    this.minQualifyingMinutes = 5,
    this.studyHour = 18,
    this.syncEnabled = true,
    this.sidebarCollapsed = false,
    this.profileName = '',
    this.use24h = false,
    this.paletteId = 'ocean',
    this.accentColor = 0,
    this.amoled = false,
    this.fontScale = 1.0,
    this.focusWorkMin = 25,
    this.focusBreakMin = 5,
    this.ambientSound = 'off',
    this.ambientVolume = 0.5,
    this.streakFreeze = true,
  });
  final ThemeMode themeMode;
  final int dailyTargetMinutes, weekStart, minQualifyingMinutes, studyHour;
  final bool syncEnabled, sidebarCollapsed, use24h, amoled, streakFreeze;
  final String profileName, paletteId, ambientSound;

  /// ARGB value of a custom accent colour, or 0 to use the palette's own.
  final int accentColor;
  final double fontScale, ambientVolume;
  final int focusWorkMin, focusBreakMin;

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? dailyTargetMinutes,
    int? weekStart,
    int? minQualifyingMinutes,
    int? studyHour,
    bool? syncEnabled,
    bool? sidebarCollapsed,
    String? profileName,
    bool? use24h,
    String? paletteId,
    int? accentColor,
    bool? amoled,
    double? fontScale,
    int? focusWorkMin,
    int? focusBreakMin,
    String? ambientSound,
    double? ambientVolume,
    bool? streakFreeze,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        dailyTargetMinutes: dailyTargetMinutes ?? this.dailyTargetMinutes,
        weekStart: weekStart ?? this.weekStart,
        minQualifyingMinutes: minQualifyingMinutes ?? this.minQualifyingMinutes,
        studyHour: studyHour ?? this.studyHour,
        syncEnabled: syncEnabled ?? this.syncEnabled,
        sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
        profileName: profileName ?? this.profileName,
        use24h: use24h ?? this.use24h,
        paletteId: paletteId ?? this.paletteId,
        accentColor: accentColor ?? this.accentColor,
        amoled: amoled ?? this.amoled,
        fontScale: fontScale ?? this.fontScale,
        focusWorkMin: focusWorkMin ?? this.focusWorkMin,
        focusBreakMin: focusBreakMin ?? this.focusBreakMin,
        ambientSound: ambientSound ?? this.ambientSound,
        ambientVolume: ambientVolume ?? this.ambientVolume,
        streakFreeze: streakFreeze ?? this.streakFreeze,
      );

  static Future<AppSettings> load(AppDatabase db) async {
    Future<String?> g(String k) => db.pref(k);
    int i(String? v, int d) => int.tryParse(v ?? '') ?? d;
    double f(String? v, double d) => double.tryParse(v ?? '') ?? d;
    return AppSettings(
      themeMode: switch (await g('theme')) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      },
      dailyTargetMinutes: i(await g('dailyTarget'), 60),
      weekStart: i(await g('weekStart'), DateTime.monday),
      minQualifyingMinutes: i(await g('minQualifying'), 5),
      studyHour: i(await g('studyHour'), 18),
      syncEnabled: (await g('syncEnabled')) != '0',
      sidebarCollapsed: (await g('sidebarCollapsed')) == '1',
      profileName: await g('profileName') ?? '',
      use24h: (await g('use24h')) == '1',
      paletteId: await g('palette') ?? 'ocean',
      accentColor: i(await g('accentColor'), 0),
      amoled: (await g('amoled')) == '1',
      fontScale: f(await g('fontScale'), 1.0).clamp(0.85, 1.4),
      focusWorkMin: i(await g('focusWork'), 25).clamp(1, 180),
      focusBreakMin: i(await g('focusBreak'), 5).clamp(1, 60),
      ambientSound: await g('ambientSound') ?? 'off',
      ambientVolume: f(await g('ambientVolume'), 0.5).clamp(0.0, 1.0),
      streakFreeze: (await g('streakFreeze')) != '0',
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(initialSettingsProvider);

  Future<void> update(AppSettings s) async {
    final old = state;
    state = s;
    final db = ref.read(dbProvider);
    // Only write what changed: sliders call this many times a second.
    Future<void> put(String key, Object? now, Object? before, [String Function(Object?)? fmt]) async {
      if (now == before) return;
      await db.setPref(key, fmt == null ? '$now' : fmt(now));
    }

    String flag(Object? v) => v == true ? '1' : '0';
    await put('theme', s.themeMode.name, old.themeMode.name);
    await put('dailyTarget', s.dailyTargetMinutes, old.dailyTargetMinutes);
    await put('weekStart', s.weekStart, old.weekStart);
    await put('minQualifying', s.minQualifyingMinutes, old.minQualifyingMinutes);
    await put('studyHour', s.studyHour, old.studyHour);
    await put('syncEnabled', s.syncEnabled, old.syncEnabled, flag);
    await put('sidebarCollapsed', s.sidebarCollapsed, old.sidebarCollapsed, flag);
    await put('profileName', s.profileName, old.profileName);
    await put('use24h', s.use24h, old.use24h, flag);
    await put('palette', s.paletteId, old.paletteId);
    await put('accentColor', s.accentColor, old.accentColor);
    await put('amoled', s.amoled, old.amoled, flag);
    await put('fontScale', s.fontScale, old.fontScale);
    await put('focusWork', s.focusWorkMin, old.focusWorkMin);
    await put('focusBreak', s.focusBreakMin, old.focusBreakMin);
    await put('ambientSound', s.ambientSound, old.ambientSound);
    await put('ambientVolume', s.ambientVolume, old.ambientVolume);
    await put('streakFreeze', s.streakFreeze, old.streakFreeze, flag);
  }
}

final initialSettingsProvider = Provider<AppSettings>((ref) => const AppSettings());

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
