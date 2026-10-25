import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/colors/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/seed_data.dart';
import '../utils/app_snack.dart';
import 'section_card.dart';

class OnboardingCard extends ConsumerWidget {
  const OnboardingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: 'Welcome to Lumora',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
            'Nothing is tracked yet — every number on this page is computed from what you record. Start with one of these:',
            style: TextStyle(color: Palette.muted)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(
              onPressed: () async {
                final n = await addStarterSubjects(ref.read(repoProvider));
                if (context.mounted) toast(context, 'Added $n starter subjects — edit or remove any of them.');
              },
              icon: const Icon(Icons.library_add_outlined),
              label: const Text('Add starter subjects')),
          OutlinedButton.icon(
              onPressed: () => context.go('/goals?new=1'),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Create a goal')),
          OutlinedButton.icon(
              onPressed: () => context.go('/sessions'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start a session')),
        ]),
      ]),
    );
  }
}
