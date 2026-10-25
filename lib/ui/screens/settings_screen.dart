import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/colors/app_colors.dart';
import '../widgets/account_sync_card.dart';
import '../widgets/appearance_card.dart';
import '../widgets/availability_card.dart';
import '../widgets/backup_settings_card.dart';
import '../widgets/local_account_card.dart';
import '../widgets/lumora_logo.dart';
import '../widgets/page_layout.dart';
import '../widgets/preferences_card.dart';
import '../widgets/section_card.dart';
import '../../core/utils/responsive.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageBody(maxWidth: 1200, children: [
      const PageHeader(title: 'Settings', subtitle: 'Preferences, availability, sync and data'),
      AdaptiveGrid(minTile: 520, maxColumns: 2, spacing: 16, children: const [
        PreferencesCard(),
        AppearanceCard(),
        AvailabilityCard(),
        LocalAccountCard(),
        AccountSyncCard(),
        BackupSettingsCard(),
      ]),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Notifications',
        child: const Text(
            'Reminders and coaching tips appear in the in-app notification center (the bell). Native OS notifications are not enabled in this build; '
            'nothing requires internet access or Firebase Cloud Messaging.',
            style: TextStyle(color: Palette.muted)),
      ),
      const SizedBox(height: 16),
      SectionCard(
        child: Row(children: [
          const LumoraLogo(size: 48),
          const SizedBox(width: 14),
          const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Lumora — Learning Tracker', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text('Offline-first. Your data lives in a local SQLite database on this device.', style: TextStyle(color: Palette.muted)),
          ])),
        ]),
      ),
    ]);
  }
}
