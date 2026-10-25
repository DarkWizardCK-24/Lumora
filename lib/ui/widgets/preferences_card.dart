import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/colors/app_colors.dart';
import '../../core/providers/settings_provider.dart';
import 'section_card.dart';

/// Appearance, learning targets and streak rules. Persisted locally.
class PreferencesCard extends ConsumerStatefulWidget {
  const PreferencesCard({super.key});
  @override
  ConsumerState<PreferencesCard> createState() => _PreferencesCardState();
}

class _PreferencesCardState extends ConsumerState<PreferencesCard> {
  late final _name = TextEditingController(text: ref.read(settingsProvider).profileName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    return SectionCard(
      title: 'Preferences',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Local profile name', helperText: 'Shown in greetings. Stays on this device.'),
          onChanged: (v) => n.update(ref.read(settingsProvider).copyWith(profileName: v.trim())),
        ),
        const SizedBox(height: 16),
        const Text('Theme', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (mode, label, icon) in const [
            (ThemeMode.light, 'Light', Icons.light_mode_outlined),
            (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
            (ThemeMode.system, 'System', Icons.brightness_auto_outlined),
          ])
            ChoiceChip(
              avatar: Icon(icon, size: 18),
              label: Text(label),
              selected: s.themeMode == mode,
              onSelected: (_) => n.update(s.copyWith(themeMode: mode)),
            ),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _drop<int>(context, 'Daily learning target', s.dailyTargetMinutes, {for (final m in [15, 30, 45, 60, 90, 120, 180, 240]) m: m < 60 ? '$m min' : '${m / 60} h'},
              (v) => n.update(s.copyWith(dailyTargetMinutes: v))),
          _drop<int>(context, 'Week starts on', s.weekStart, const {DateTime.monday: 'Monday', DateTime.sunday: 'Sunday'}, (v) => n.update(s.copyWith(weekStart: v))),
          _drop<int>(context, 'Streak: min minutes per day', s.minQualifyingMinutes, {for (final m in [1, 5, 10, 15, 30]) m: '$m min'},
              (v) => n.update(s.copyWith(minQualifyingMinutes: v))),
          _drop<int>(context, 'Preferred study hour', s.studyHour, {for (var h = 5; h <= 23; h++) h: '${h.toString().padLeft(2, '0')}:00'},
              (v) => n.update(s.copyWith(studyHour: v))),
        ]),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('24-hour time'),
          value: s.use24h,
          onChanged: (v) => n.update(s.copyWith(use24h: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Streak freeze'),
          subtitle: const Text('One missed day per week will not break your streak.'),
          value: s.streakFreeze,
          onChanged: (v) => n.update(s.copyWith(streakFreeze: v)),
        ),
        const Text(
            'A day counts toward your streak when it has at least the minutes above in completed sessions, or a solved coding problem.',
            style: TextStyle(color: Palette.muted, fontSize: 12.5)),
      ]),
    );
  }

  Widget _drop<T>(BuildContext c, String label, T value, Map<T, String> options, ValueChanged<T> onChanged) {
    return SizedBox(
      width: 230,
      child: DropdownButtonFormField<T>(
        initialValue: options.containsKey(value) ? value : options.keys.first,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (v) => v == null ? null : onChanged(v),
      ),
    );
  }
}
