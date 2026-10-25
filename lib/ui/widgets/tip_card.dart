import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/colors/app_colors.dart';
import '../../core/colors/status_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/coach_service.dart';
import '../../core/services/repository.dart';

class TipCard extends StatelessWidget {
  const TipCard(this.tip, {super.key});
  final Tip tip;
  @override
  Widget build(BuildContext context) => TipTile(tip);
}

class TipTile extends ConsumerWidget {
  const TipTile(this.tip, {super.key, this.onDone});
  final Tip tip;
  final VoidCallback? onDone;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = tipColor(tip.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lightbulb_outline_rounded, color: c, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(tip.title, style: const TextStyle(fontWeight: FontWeight.w700))),
          IconButton(
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => ref.read(repoProvider).dismissTip(tip.key, tip.fingerprint),
          ),
        ]),
        Text('Why: ${tip.why}', style: const TextStyle(color: Palette.muted, fontSize: 13)),
        const SizedBox(height: 4),
        Text(tip.recommendation),
        if (tip.route != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              onDone?.call();
              context.go(tip.route!);
            },
            child: Text(tip.actionLabel ?? 'Open'),
          ),
        ],
      ]),
    );
  }
}
