import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/colors/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/repository.dart';
import 'section_card.dart';

/// Study minutes available per weekday. Smart Analysis and the schedule
/// generator never plan beyond these limits.
class AvailabilityCard extends ConsumerWidget {
  const AvailabilityCard({super.key});
  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(snapshotProvider).value;
    final repo = ref.read(repoProvider);
    return SectionCard(
      title: 'Study availability',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('How much time can you realistically study each day? Forecasts and generated plans stay within these limits.',
            style: TextStyle(color: Palette.muted)),
        const SizedBox(height: 12),
        if (snap == null)
          const LinearProgressIndicator()
        else
          for (var d = 1; d <= 7; d++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                SizedBox(width: 96, child: Text(_days[d - 1])),
                Expanded(
                  child: Slider(
                    value: (snap.availability[d] ?? 0).toDouble().clamp(0, 480),
                    max: 480,
                    divisions: 32,
                    label: _fmt(snap.availability[d] ?? 0),
                    onChanged: (v) => repo.setAvailability(d, v.round()),
                  ),
                ),
                SizedBox(width: 58, child: Text(_fmt(snap.availability[d] ?? 0), textAlign: TextAlign.end)),
              ]),
            ),
      ]),
    );
  }

  String _fmt(int m) => m == 0 ? 'Off' : m < 60 ? '${m}m' : '${m ~/ 60}h${m % 60 == 0 ? '' : ' ${m % 60}m'}';
}
