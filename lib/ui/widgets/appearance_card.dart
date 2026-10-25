import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors/app_colors.dart';
import '../../core/colors/theme_palettes.dart';
import '../../core/providers/settings_provider.dart';
import 'section_card.dart';

/// Colour palette, custom accent, true-black dark mode and text size.
class AppearanceCard extends ConsumerWidget {
  const AppearanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final primary = Theme.of(context).colorScheme.primary;
    return SectionCard(
      title: 'Appearance',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Palette', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final p in appPalettes)
            _PaletteTile(
              palette: p,
              selected: s.accentColor == 0 && s.paletteId == p.id,
              onTap: () {
                HapticFeedback.selectionClick();
                n.update(s.copyWith(paletteId: p.id, accentColor: 0));
              },
            ),
        ]),
        const SizedBox(height: 18),
        const Text('Custom accent', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final c in accentSwatches)
            Semantics(
              button: true,
              label: 'Accent colour ${c.toRadixString(16)}',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  HapticFeedback.selectionClick();
                  n.update(s.copyWith(accentColor: c));
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: s.accentColor == c ? Theme.of(context).colorScheme.onSurface : Colors.transparent, width: 3),
                  ),
                  child: s.accentColor == c ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
                ),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('AMOLED black'),
          subtitle: const Text('True black backgrounds in dark mode. Saves battery on OLED screens.'),
          value: s.amoled,
          onChanged: (v) => n.update(s.copyWith(amoled: v)),
        ),
        const SizedBox(height: 4),
        Row(children: [
          const Expanded(child: Text('Text size', overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Text('${(s.fontScale * 100).round()}%', style: TextStyle(color: primary, fontWeight: FontWeight.w700)),
        ]),
        Slider(
          min: 0.85,
          max: 1.4,
          divisions: 11,
          value: s.fontScale.clamp(0.85, 1.4),
          label: '${(s.fontScale * 100).round()}%',
          onChanged: (v) => n.update(s.copyWith(fontScale: double.parse(v.toStringAsFixed(2)))),
        ),
        const Text('Colours and text size apply instantly across the app and are stored only on this device.',
            style: TextStyle(color: Palette.muted, fontSize: 12.5)),
      ]),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({required this.palette, required this.selected, required this.onTap});
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '${palette.name} palette',
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 104,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: selected ? palette.seed : t.dividerTheme.color ?? Palette.border, width: selected ? 2 : 1),
            color: selected ? palette.seed.withValues(alpha: 0.08) : null,
          ),
          child: Column(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [palette.seed, Color.lerp(palette.seed, Colors.black, 0.35)!]),
              ),
              child: Icon(palette.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            Text(palette.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}
