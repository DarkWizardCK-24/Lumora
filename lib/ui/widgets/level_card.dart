import 'package:flutter/material.dart';
import '../../core/colors/app_colors.dart';
import '../../core/services/streak_engine.dart';
import '../../core/services/xp_engine.dart';
import 'confetti.dart';
import 'pill.dart';
import 'progress_bar.dart';
import 'progress_ring.dart';

Color tierColor(AvatarTier t) => switch (t) {
      AvatarTier.starter => const Color(0xFF64748B),
      AvatarTier.bronze => const Color(0xFFCD7F32),
      AvatarTier.silver => const Color(0xFF94A3B8),
      AvatarTier.gold => const Color(0xFFF59E0B),
      AvatarTier.diamond => const Color(0xFF22D3EE),
    };

String tierName(AvatarTier t) => switch (t) {
      AvatarTier.starter => 'Starter',
      AvatarTier.bronze => 'Bronze',
      AvatarTier.silver => 'Silver',
      AvatarTier.gold => 'Gold',
      AvatarTier.diamond => 'Diamond',
    };

/// Ring around the avatar that reflects the learner's level tier.
class TierAvatar extends StatelessWidget {
  const TierAvatar({super.key, required this.tier, required this.child});
  final AvatarTier tier;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = tierColor(tier);
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: tier == AvatarTier.starter
            ? null
            : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c, Color.lerp(c, Colors.white, 0.45)!, c]),
        border: tier == AvatarTier.starter ? Border.all(color: c.withValues(alpha: 0.4), width: 1.5) : null,
      ),
      child: child,
    );
  }
}

/// Level, XP progress and streak-freeze status. Tap for the full XP breakdown.
class LevelCard extends StatelessWidget {
  const LevelCard(this.xp, this.streak, {super.key});
  final XpInfo xp;
  final StreakInfo streak;

  @override
  Widget build(BuildContext context) {
    final color = tierColor(xp.tier);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: () => showXpBreakdown(context, xp),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            ProgressRing(
              value: xp.progress,
              size: 86,
              stroke: 9,
              color: color,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('LV', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: color, fontWeight: FontWeight.w700)),
                Text('${xp.level}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1)),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(xp.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text('${xp.xp} XP · ${xp.toNext} to level ${xp.level + 1}', style: const TextStyle(color: Palette.muted, fontSize: 12.5)),
                const SizedBox(height: 8),
                ProgressBar(xp.progress, color: color, height: 7),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  Pill('${tierName(xp.tier)} frame', color: color, icon: Icons.workspace_premium_rounded),
                  if (streak.frozenDays.isNotEmpty || streak.freezeReady)
                    Pill(streak.freezeReady ? 'Streak freeze ready' : 'Freeze used this week',
                        color: streak.freezeReady ? const Color(0xFF0284C7) : Palette.muted, icon: Icons.ac_unit_rounded),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

Future<void> showXpBreakdown(BuildContext context, XpInfo xp) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Text('Level ${xp.level} · ${xp.title}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${xp.xp} XP total · next level at ${xp.nextLevelXp} XP', style: const TextStyle(color: Palette.muted)),
          const SizedBox(height: 16),
          const Text('Where your XP comes from', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (xp.sources.isEmpty)
            const Text('Complete a session, solve a problem or review a flashcard to earn your first XP.',
                style: TextStyle(color: Palette.muted)),
          for (final s in xp.sources)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(s.detail),
              trailing: Text('+${s.xp}', style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.success)),
            ),
          const Divider(height: 28),
          const Text('Avatar frames', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final (tier, from) in const [
            (AvatarTier.starter, 1),
            (AvatarTier.bronze, 3),
            (AvatarTier.silver, 5),
            (AvatarTier.gold, 10),
            (AvatarTier.diamond, 15),
          ])
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: TierAvatar(tier: tier, child: const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16))),
              title: Text('${tierName(tier)} frame'),
              subtitle: Text('Unlocks at level $from'),
              trailing: xp.level >= from
                  ? const Icon(Icons.check_circle_rounded, color: Palette.success)
                  : const Icon(Icons.lock_outline_rounded, color: Palette.muted),
            ),
          const SizedBox(height: 8),
          const Text('XP is calculated from your saved records, so deleting or backdating entries adjusts it automatically.',
              style: TextStyle(color: Palette.muted, fontSize: 12)),
        ],
      ),
    ),
  );
}

/// Celebration shown once when the level passes the highest one seen before.
Future<void> showLevelUp(BuildContext context, XpInfo xp) {
  return showDialog<void>(
    context: context,
    builder: (c) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(alignment: Alignment.center, children: [
        const Positioned.fill(child: ConfettiBurst()),
        Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(color: Theme.of(c).colorScheme.surface, borderRadius: BorderRadius.circular(Radii.lg + 6)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 650),
              curve: Curves.elasticOut,
              builder: (context, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [tierColor(xp.tier), Color.lerp(tierColor(xp.tier), Colors.white, 0.4)!]),
                ),
                child: Text('${xp.level}', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('LEVEL UP!', style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 6),
            Text(xp.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${xp.xp} XP · ${xp.toNext} more for level ${xp.level + 1}', style: const TextStyle(color: Palette.muted)),
            if (const {3, 5, 10, 15}.contains(xp.level)) ...[
              const SizedBox(height: 12),
              Pill('New avatar frame: ${tierName(xp.tier)}', color: tierColor(xp.tier), icon: Icons.workspace_premium_rounded),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Keep going')),
          ]),
        ),
      ]),
    ),
  );
}
