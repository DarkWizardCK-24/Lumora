import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/colors/app_colors.dart';
import '../../core/colors/theme_palettes.dart';
import '../../core/models/enums.dart';
import '../../core/models/study_session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/focus_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/ambient_player.dart';
import '../../core/services/pomodoro.dart';
import '../../core/services/repository.dart';
import '../../core/services/snapshot.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/pickers.dart';
import '../utils/app_snack.dart';
import '../widgets/progress_ring.dart';

/// Full-screen, distraction-free Pomodoro timer with ambient sound and an end-of-session reflection.
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});
  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  Timer? _tick;
  String? _subjectId, _topicId, _goalId;
  SessionType _type = SessionType.learning;
  bool _busy = false, _fullscreen = false;
  // `ref` must not be used inside dispose(), so keep what teardown needs.
  late final ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    // Resume the user's saved ambient sound if a focus session is already running.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(focusProvider).running) _applySound(ref.read(settingsProvider).ambientSound);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    if (_fullscreen) _setFullscreen(false);
    // Ambient sound keeps playing while a focus session runs in the background.
    if (!_container.read(focusProvider).running) _container.read(ambientPlayerProvider).stop();
    super.dispose();
  }

  Future<void> _setFullscreen(bool on) async {
    if (kIsWeb || !Platform.isWindows) return;
    await windowManager.setFullScreen(on);
    if (mounted) setState(() => _fullscreen = on);
  }

  void _applySound(String id) {
    final sound = AmbientSound.byId(id);
    ref.read(ambientPlayerProvider).play(sound, ref.read(settingsProvider).ambientVolume);
  }

  void _leave() => context.canPop() ? context.pop() : context.go('/sessions');

  Future<void> _guard(Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() => _guard(() async {
        await ref.read(focusProvider.notifier).begin(subjectId: _subjectId, topicId: _topicId, goalId: _goalId, type: _type);
        _applySound(ref.read(settingsProvider).ambientSound);
      });

  Future<void> _finish(StudySession s) => _guard(() async {
        final r = await showDialog<({int? rating, String line})>(context: context, builder: (c) => const _ReflectionDialog());
        if (r == null) return; // keep focusing
        final repo = ref.read(repoProvider);
        await repo.finishSession(s, notes: r.line, rating: r.rating);
        await repo.award('first-session');
        ref.read(focusProvider.notifier).end();
        if (!mounted) return;
        toast(context, 'Session saved');
        context.go('/sessions');
      });

  @override
  Widget build(BuildContext context) {
    ref.listen<FocusState>(focusProvider, (prev, next) {
      if (prev != null && next.changes != prev.changes && mounted) {
        toast(context, next.lastChangeToBreak ? 'Focus block done. Take a break.' : 'Break over. Back to focus.');
      }
    });
    final focus = ref.watch(focusProvider);
    final active = ref.watch(activeSessionProvider).value;
    final snap = ref.watch(snapshotProvider).value;
    final primary = Theme.of(context).colorScheme.primary;
    final settings = ref.watch(settingsProvider);
    final onBreak = focus.pomodoro?.onBreak ?? false;
    final tint = onBreak ? Palette.success : primary;
    final dark = buildTheme(Brightness.dark, seed: seedFor(settings.paletteId, settings.accentColor), amoled: settings.amoled);

    return Theme(
      data: dark,
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.space): _PauseIntent(),
          SingleActivator(LogicalKeyboardKey.escape): _LeaveIntent(),
        },
        child: Actions(
          actions: {
            _PauseIntent: CallbackAction<_PauseIntent>(onInvoke: (_) {
              if (focus.running) ref.read(focusProvider.notifier).togglePause();
              return null;
            }),
            _LeaveIntent: CallbackAction<_LeaveIntent>(onInvoke: (_) {
              _leave();
              return null;
            }),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              body: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: settings.amoled
                        ? [Colors.black, Color.lerp(Colors.black, tint, 0.18)!]
                        : [const Color(0xFF0B1220), Color.lerp(const Color(0xFF0B1220), tint, 0.32)!],
                  ),
                ),
                child: SafeArea(
                  child: Column(children: [
                    _topBar(),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: focus.running && active != null
                                ? _running(context, focus.pomodoro!, active, snap, tint)
                                : _setup(context, snap, active != null),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    final running = ref.watch(focusProvider).running;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(children: [
        IconButton(
            tooltip: running ? 'Leave focus mode (session keeps running)' : 'Back',
            onPressed: _leave,
            icon: const Icon(Icons.arrow_back_rounded)),
        const Spacer(),
        if (!kIsWeb && Platform.isWindows)
          IconButton(
              tooltip: _fullscreen ? 'Exit full screen' : 'Full screen',
              onPressed: () => _setFullscreen(!_fullscreen),
              icon: Icon(_fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded)),
      ]),
    );
  }

  // ---------------------------------------------------------------- setup ---

  Widget _setup(BuildContext context, Snapshot? snap, bool hasActive) {
    final settings = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    Widget dd<T>(String label, T? value, Map<T, String> options, ValueChanged<T?> onChanged) => DropdownButtonFormField<T?>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            DropdownMenuItem<T?>(value: null, child: const Text('None')),
            for (final e in options.entries) DropdownMenuItem<T?>(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: onChanged,
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.self_improvement_rounded, size: 56, color: Colors.white70),
      const SizedBox(height: 12),
      const Text('Focus mode', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 6),
      Text(
          hasActive
              ? 'A study session is already running. Enter focus mode to continue it with Pomodoro blocks.'
              : 'One distraction-free screen. Work in blocks, rest in breaks.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 24),
      if (!hasActive && snap != null) ...[
        dd<String>('Subject', _subjectId, subjectOptions(snap), (v) => setState(() {
              _subjectId = v;
              _topicId = null;
            })),
        const SizedBox(height: 12),
        dd<String>('Topic', _topicId, topicOptions(snap, subjectId: _subjectId), (v) => setState(() => _topicId = v)),
        const SizedBox(height: 12),
        dd<String>('Goal', _goalId, goalOptions(snap), (v) => setState(() => _goalId = v)),
        const SizedBox(height: 12),
        DropdownButtonFormField<SessionType>(
          initialValue: _type,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Session type'),
          items: [for (final e in SessionType.values) DropdownMenuItem(value: e, child: Text(e.label))],
          onChanged: (v) => setState(() => _type = v ?? _type),
        ),
        const SizedBox(height: 20),
      ],
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
        for (final (w, b) in const [(25, 5), (50, 10), (90, 15)])
          ChoiceChip(
            label: Text('$w / $b min'),
            selected: settings.focusWorkMin == w && settings.focusBreakMin == b,
            onSelected: (_) => n.update(settings.copyWith(focusWorkMin: w, focusBreakMin: b)),
          ),
      ]),
      const SizedBox(height: 10),
      Wrap(alignment: WrapAlignment.center, spacing: 24, runSpacing: 8, children: [
        _Stepper(label: 'Focus', value: settings.focusWorkMin, min: 5, max: 180, step: 5, onChanged: (v) => n.update(settings.copyWith(focusWorkMin: v))),
        _Stepper(label: 'Break', value: settings.focusBreakMin, min: 1, max: 60, step: 1, onChanged: (v) => n.update(settings.copyWith(focusBreakMin: v))),
      ]),
      const SizedBox(height: 22),
      _soundPicker(),
      const SizedBox(height: 26),
      FilledButton.icon(
        onPressed: _busy ? null : _start,
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(hasActive ? 'Enter focus mode' : 'Start focusing'),
        style: FilledButton.styleFrom(minimumSize: const Size(240, 56)),
      ),
      const SizedBox(height: 10),
      const Text('Every 4th break is a long one.', style: TextStyle(color: Colors.white54, fontSize: 12)),
    ]);
  }

  Widget _soundPicker() {
    final settings = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final player = ref.read(ambientPlayerProvider);
    return Column(children: [
      const Text('AMBIENT SOUND', style: TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 11, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
        for (final s in AmbientSound.values)
          ChoiceChip(
            avatar: Icon(s.icon, size: 18),
            label: Text(s.label),
            selected: settings.ambientSound == s.id,
            onSelected: (_) {
              n.update(settings.copyWith(ambientSound: s.id));
              // Preview immediately so the user hears what they are picking.
              player.play(s, settings.ambientVolume);
            },
          ),
      ]),
      if (settings.ambientSound != 'off')
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(children: [
            const Icon(Icons.volume_down_rounded, color: Colors.white54),
            Expanded(
              child: Slider(
                value: settings.ambientVolume,
                onChanged: (v) {
                  player.setVolume(v);
                  n.update(settings.copyWith(ambientVolume: double.parse(v.toStringAsFixed(2))));
                },
              ),
            ),
            const Icon(Icons.volume_up_rounded, color: Colors.white54),
          ]),
        ),
    ]);
  }

  // -------------------------------------------------------------- running ---

  Widget _running(BuildContext context, Pomodoro p, StudySessionHolder holder, Snapshot? snap, Color tint) {
    final now = nowMs();
    final remaining = p.remainingSeconds(now);
    final size = math.min(MediaQuery.sizeOf(context).width - 56, 320.0);
    final sess = holder.session;
    final studied = StudySession.computeActiveSeconds(sess.startedAt, now, holder.pauses);
    final label = p.onBreak ? (p.isLongBreak ? 'LONG BREAK' : 'BREAK') : (p.paused ? 'PAUSED' : 'FOCUS');
    final subject = snap == null ? null : subjectNameOf(snap, sess.subjectId);
    final goal = snap == null ? null : goalTitleOf(snap, sess.goalId);
    final context0 = [sess.type.label, ?subject, ?goal].join(' · ');
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('CYCLE ${p.cycle}', style: const TextStyle(color: Colors.white54, letterSpacing: 3, fontWeight: FontWeight.w700, fontSize: 12)),
      const SizedBox(height: 18),
      _Breathing(
        enabled: p.onBreak,
        child: ProgressRing(
          value: p.progress(now),
          size: size,
          stroke: 14,
          color: tint,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(color: tint, letterSpacing: 4, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            Text(_mmss(remaining),
                style: TextStyle(
                    fontSize: size * 0.24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            if (p.onBreak)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Stretch. Drink water.', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 22),
      Text(context0, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 4),
      Text('${(studied / 60).floor()} min focused this session', style: const TextStyle(color: Colors.white38, fontSize: 12.5)),
      const SizedBox(height: 22),
      Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
        if (p.onBreak)
          FilledButton.icon(
              onPressed: _busy ? null : () => ref.read(focusProvider.notifier).skipBreak(),
              icon: const Icon(Icons.skip_next_rounded),
              label: const Text('Skip break'),
              style: FilledButton.styleFrom(minimumSize: const Size(150, 52)))
        else
          FilledButton.icon(
              onPressed: _busy ? null : () => ref.read(focusProvider.notifier).togglePause(),
              icon: Icon(p.paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
              label: Text(p.paused ? 'Resume' : 'Pause'),
              style: FilledButton.styleFrom(minimumSize: const Size(150, 52))),
        OutlinedButton.icon(
            onPressed: _busy ? null : () => _finish(sess),
            icon: const Icon(Icons.flag_rounded),
            label: const Text('Finish'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(130, 52), foregroundColor: Colors.white)),
      ]),
      const SizedBox(height: 22),
      _soundPicker(),
      const SizedBox(height: 8),
      const Text('Space pauses · Esc leaves (the session keeps running)', style: TextStyle(color: Colors.white38, fontSize: 12)),
    ]);
  }

  static String _mmss(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

class _PauseIntent extends Intent {
  const _PauseIntent();
}

class _LeaveIntent extends Intent {
  const _LeaveIntent();
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.min, required this.max, required this.step, required this.onChanged});
  final String label;
  final int value, min, max, step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label.toUpperCase(), style: const TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 11, fontWeight: FontWeight.w700)),
      Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(tooltip: 'Less', onPressed: value <= min ? null : () => onChanged((value - step).clamp(min, max)), icon: const Icon(Icons.remove_circle_outline)),
        ConstrainedBox(constraints: const BoxConstraints(minWidth: 52), child: Text('$value min', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white))),
        IconButton(tooltip: 'More', onPressed: value >= max ? null : () => onChanged((value + step).clamp(min, max)), icon: const Icon(Icons.add_circle_outline)),
      ]),
    ]);
  }
}

/// Gently scales its child in and out, like a breathing guide. Static when disabled.
class _Breathing extends StatefulWidget {
  const _Breathing({required this.enabled, required this.child});
  final bool enabled;
  final Widget child;
  @override
  State<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<_Breathing> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _Breathing old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.enabled && _c.isAnimating) {
      _c.animateTo(0, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.scale(scale: 1 + 0.04 * Curves.easeInOut.transform(_c.value), child: child),
      child: widget.child);
}

/// "How focused were you?" plus a one-line takeaway.
class _ReflectionDialog extends StatefulWidget {
  const _ReflectionDialog();
  @override
  State<_ReflectionDialog> createState() => _ReflectionDialogState();
}

class _ReflectionDialogState extends State<_ReflectionDialog> {
  int? _rating;
  final _line = TextEditingController();

  static const _labels = {1: 'Distracted', 2: 'Scattered', 3: 'Okay', 4: 'Focused', 5: 'Deep focus'};

  @override
  void dispose() {
    _line.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Session reflection'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('How focused were you?', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                tooltip: '$i – ${_labels[i]}',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _rating = i);
                },
                icon: AnimatedScale(
                  scale: _rating == i ? 1.25 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(_rating != null && i <= _rating! ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 34, color: _rating != null && i <= _rating! ? Palette.warning : Palette.muted),
                ),
              ),
          ]),
          Center(child: Text(_rating == null ? 'Tap a star' : _labels[_rating]!, style: const TextStyle(color: Palette.muted))),
          const SizedBox(height: 16),
          TextField(
            controller: _line,
            maxLength: 140,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'One thing you learned'),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep focusing')),
        FilledButton(onPressed: () => Navigator.pop(context, (rating: _rating, line: _line.text.trim())), child: const Text('Save session')),
      ],
    );
  }
}
