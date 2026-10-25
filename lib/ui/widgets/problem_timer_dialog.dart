import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors/app_colors.dart';
import '../../core/models/coding_problem.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/repository.dart';
import '../../core/utils/format.dart';

/// Stopwatch for one attempt at a problem. Saving records the time so improvement can be tracked.
Future<void> showProblemTimer(BuildContext context, CodingProblem p) =>
    showDialog<void>(context: context, barrierDismissible: false, builder: (c) => _TimerDialog(p));

class _TimerDialog extends ConsumerStatefulWidget {
  const _TimerDialog(this.problem);
  final CodingProblem problem;
  @override
  ConsumerState<_TimerDialog> createState() => _TimerDialogState();
}

enum _Phase { idle, running, stopped }

class _TimerDialogState extends ConsumerState<_TimerDialog> {
  final _watch = Stopwatch();
  Timer? _tick;
  _Phase _phase = _Phase.idle;
  bool _saving = false;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _start() {
    HapticFeedback.selectionClick();
    _watch.start();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) => setState(() {}));
    setState(() => _phase = _Phase.running);
  }

  void _stop() {
    HapticFeedback.selectionClick();
    _watch.stop();
    _tick?.cancel();
    setState(() => _phase = _Phase.stopped);
  }

  Future<void> _save(bool solved) async {
    if (_saving) return;
    setState(() => _saving = true);
    await ref.read(repoProvider).recordAttempt(widget.problem, _watch.elapsed.inSeconds.clamp(1, 1 << 30), solved: solved);
    if (mounted) Navigator.pop(context);
  }

  String get _clock {
    final s = _watch.elapsed.inSeconds;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(s ~/ 3600)}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final running = _phase == _Phase.running;
    return AlertDialog(
      title: Text(widget.problem.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_clock,
            style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w700,
                color: running ? Theme.of(context).colorScheme.primary : null,
                fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(height: 4),
        Text(
            switch (_phase) {
              _Phase.idle => 'Start when you begin reading the problem.',
              _Phase.running => 'Timing your attempt…',
              _Phase.stopped => 'How did it go?',
            },
            style: const TextStyle(color: Palette.muted)),
        if (_phase == _Phase.stopped) ...[
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Palette.success),
                    onPressed: _saving ? null : () => _save(true),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Solved'))),
            const SizedBox(width: 10),
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: _saving ? null : () => _save(false),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Not solved'))),
          ]),
          const SizedBox(height: 6),
          Text('Saves ${fmtMinutes((_watch.elapsed.inSeconds / 60).ceil())} to this problem', style: const TextStyle(color: Palette.muted, fontSize: 12)),
        ],
      ]),
      actions: [
        if (_phase != _Phase.stopped) TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        if (_phase == _Phase.idle) FilledButton.icon(onPressed: _start, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Start')),
        if (running) FilledButton.icon(onPressed: _stop, icon: const Icon(Icons.stop_rounded), label: const Text('Stop')),
        if (_phase == _Phase.stopped) TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Discard')),
      ],
    );
  }
}
