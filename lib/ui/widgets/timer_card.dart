import 'package:flutter/material.dart';
import '../../core/colors/app_colors.dart';
import '../../core/models/enums.dart';
import '../../core/models/study_session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/snapshot.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/pickers.dart';
import '../../core/utils/responsive.dart';

String _clock(int seconds) {
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(s)}';
}

class TimerCard extends StatelessWidget {
  const TimerCard({super.key, 
    required this.active,
    required this.snap,
    required this.busy,
    required this.subjectId,
    required this.topicId,
    required this.goalId,
    required this.type,
    required this.onChange,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onCancel,
  });
  final StudySessionHolder? active;
  final Snapshot snap;
  final bool busy;
  final String? subjectId, topicId, goalId;
  final SessionType type;
  final void Function(String?, String?, String?, SessionType) onChange;
  final VoidCallback onStart, onPause, onResume, onStop, onCancel;

  @override
  Widget build(BuildContext context) {
    final running = active != null;
    final paused = running && active!.session.status == SessionStatus.paused;
    final secs = running
        ? StudySession.computeActiveSeconds(active!.session.startedAt, nowMs(), active!.pauses)
        : 0;
    final compact = Responsive.isCompact(context);
    final t = Theme.of(context);
    final sess = active?.session;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: running ? (paused ? Grads.amber : Grads.sky) : [t.colorScheme.surface, t.colorScheme.surface]),
        ),
        padding: EdgeInsets.all(compact ? 16 : 28),
        child: Column(children: [
          Text(running ? (paused ? 'PAUSED' : 'FOCUSING') : 'READY',
              style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w700, color: running ? Colors.white70 : Palette.muted)),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(_clock(secs),
                style: TextStyle(
                    fontSize: compact ? 54 : 72,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: running ? Colors.white : t.colorScheme.onSurface)),
          ),
          if (running)
            Text(
                [
                  (sess!.type).label,
                  if (subjectNameOf(snap, sess.subjectId) != null) subjectNameOf(snap, sess.subjectId)!,
                  if (goalTitleOf(snap, sess.goalId) != null) goalTitleOf(snap, sess.goalId)!,
                ].join(' · '),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 18),
          if (!running) ...[
            Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
              SizedBox(
                width: compact ? double.infinity : 230,
                child: DropdownButtonFormField<String?>(
                  initialValue: subjectId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    for (final e in subjectOptions(snap).entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => onChange(v, null, goalId, type),
                ),
              ),
              SizedBox(
                width: compact ? double.infinity : 230,
                child: DropdownButtonFormField<String?>(
                  key: ValueKey('topic-$subjectId'),
                  initialValue: topicId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Topic'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    for (final e in topicOptions(snap, subjectId: subjectId).entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => onChange(subjectId, v, goalId, type),
                ),
              ),
              SizedBox(
                width: compact ? double.infinity : 230,
                child: DropdownButtonFormField<String?>(
                  initialValue: goalId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Goal'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    for (final e in goalOptions(snap).entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => onChange(subjectId, topicId, v, type),
                ),
              ),
              SizedBox(
                width: compact ? double.infinity : 230,
                child: DropdownButtonFormField<SessionType>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Session type'),
                  items: [for (final e in SessionType.values) DropdownMenuItem(value: e, child: Text(e.label))],
                  onChanged: (v) => onChange(subjectId, topicId, goalId, v!),
                ),
              ),
            ]),
            const SizedBox(height: 18),
            FilledButton.icon(
                onPressed: busy ? null : onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start session'),
                style: FilledButton.styleFrom(minimumSize: const Size(220, 54))),
          ] else
            Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
              FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Palette.ink, minimumSize: const Size(140, 52)),
                  onPressed: busy ? null : (paused ? onResume : onPause),
                  icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                  label: Text(paused ? 'Resume' : 'Pause')),
              FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Palette.ink, minimumSize: const Size(140, 52)),
                  onPressed: busy ? null : onStop,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop & save')),
              OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70), minimumSize: const Size(120, 52)),
                  onPressed: busy ? null : onCancel,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancel')),
            ]),
        ]),
      ),
    );
  }
}
