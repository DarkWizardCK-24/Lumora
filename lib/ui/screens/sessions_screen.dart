import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors/app_colors.dart';
import '../../core/models/enums.dart';
import '../../core/models/study_session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/repository.dart';
import '../../core/services/snapshot.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/format.dart';
import '../../core/utils/pickers.dart';
import '../utils/app_snack.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/form_dialog.dart';
import '../widgets/new_action_scope.dart';
import '../widgets/page_layout.dart';
import '../widgets/section_card.dart';
import '../widgets/timer_card.dart';

final int _appLaunchMs = nowMs();

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});
  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  Timer? _tick;
  String? subjectId, topicId, goalId;
  SessionType type = SessionType.learning;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() f) async {
    if (_busy) return; // swallow rapid repeated taps
    setState(() => _busy = true);
    try {
      await f();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish(StudySession s) async {
    final v = await showForm(context,
        title: 'Save session',
        submitLabel: 'Save',
        fields: [
          const FText('notes', 'What did you learn?', multiline: true),
          const FChoice('rating', 'Productivity', {'1': '1 – Distracted', '2': '2', '3': '3 – Okay', '4': '4', '5': '5 – Deep focus'}, allowNone: true),
        ],
        initial: {'notes': s.notes});
    if (v == null) return;
    final repo = ref.read(repoProvider);
    await repo.finishSession(s, notes: (v['notes'] as String?) ?? '', rating: int.tryParse((v['rating'] as String?) ?? ''));
    await repo.award('first-session');
    if (mounted) toast(context, 'Session saved');
  }

  Future<void> _addPast(Snapshot snap) async {
    final v = await showForm(context,
        title: 'Add past session',
        fields: [
          FChoice('subjectId', 'Subject', subjectOptions(snap), allowNone: true),
          FChoice('goalId', 'Goal', goalOptions(snap), allowNone: true),
          FChoice('type', 'Type', enumOptions(SessionType.values, (e) => e.label)),
          const FDateTime('start', 'Started at'),
          const FNumber('minutes', 'Duration', required: true, suffix: 'minutes'),
          const FText('notes', 'Notes', multiline: true),
        ],
        initial: {'type': 'learning', 'start': DateTime.now().subtract(const Duration(hours: 1))});
    if (v == null) return;
    final start = ((v['start'] as DateTime?) ?? DateTime.now()).millisecondsSinceEpoch;
    final mins = (v['minutes'] as int?) ?? 0;
    if (mins <= 0) return;
    await ref.read(repoProvider).saveSession(StudySession(
          subjectId: v['subjectId'] as String?,
          goalId: v['goalId'] as String?,
          type: SessionType.values.byName((v['type'] as String?) ?? 'learning'),
          startedAt: start,
          endedAt: start + mins * 60000,
          activeSeconds: mins * 60,
          status: SessionStatus.completed,
          notes: (v['notes'] as String?) ?? '',
        ));
    await ref.read(repoProvider).award('first-session');
  }

  @override
  Widget build(BuildContext context) {
    final snapAsync = ref.watch(snapshotProvider);
    final active = ref.watch(activeSessionProvider).value;
    return snapAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(e),
      data: (snap) {
        final repo = ref.read(repoProvider);
        final history = snap.sessions.take(40).toList();
        final recovered = active != null && active.session.startedAt < _appLaunchMs;
        return NewActionScope(
          onNew: () => _addPast(snap),
          child: PageBody(maxWidth: 1100, children: [
            PageHeader(title: 'Study Sessions', subtitle: 'Duration is calculated from saved timestamps, so it survives restarts', actions: [
              OutlinedButton.icon(onPressed: () => _addPast(snap), icon: const Icon(Icons.history), label: const Text('Add past session')),
            ]),
            if (recovered && active.session.status == SessionStatus.running)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Palette.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: Palette.warning.withValues(alpha: 0.4))),
                child: const Row(children: [
                  Icon(Icons.restore, color: Palette.warning),
                  SizedBox(width: 10),
                  Expanded(child: Text('Session recovered after restart. Time kept running; finish it, pause it, or discard it below.')),
                ]),
              ),
            TimerCard(
              active: active,
              snap: snap,
              busy: _busy,
              subjectId: subjectId,
              topicId: topicId,
              goalId: goalId,
              type: type,
              onChange: (sub, top, goal, t) => setState(() {
                subjectId = sub;
                topicId = top;
                goalId = goal;
                type = t;
              }),
              onStart: () => _guard(() => repo.startSession(subjectId: subjectId, topicId: topicId, goalId: goalId, type: type)),
              onPause: () => _guard(() => repo.pauseSession(active!.session)),
              onResume: () => _guard(() => repo.resumeSession(active!.session)),
              onStop: () => _guard(() => _finish(active!.session)),
              onCancel: () => _guard(() async {
                if (await confirm(context, 'Discard this session?', 'The time tracked so far will not be saved.', action: 'Discard')) {
                  await repo.discardSession(active!.session);
                }
              }),
            ),
            const SizedBox(height: 20),
            SectionCard(
              title: 'History',
              child: history.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Completed sessions appear here.', style: TextStyle(color: Palette.muted)))
                  : Column(children: [
                      for (final x in history)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), child: Icon(Icons.timer_outlined, color: Theme.of(context).colorScheme.primary)),
                          title: Text([
                            fmtMinutes(x.activeSeconds / 60),
                            x.type.label,
                            if (subjectNameOf(snap, x.subjectId) != null) subjectNameOf(snap, x.subjectId)!,
                          ].join(' · ')),
                          subtitle: Text(
                              '${fmtDateTime(fromMs(x.startedAt))}${goalTitleOf(snap, x.goalId) != null ? ' · ${goalTitleOf(snap, x.goalId)}' : ''}'
                              '${x.notes.isNotEmpty ? '\n${x.notes}' : ''}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            tooltip: 'Delete session',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              if (await confirm(context, 'Delete session?', 'This removes ${fmtMinutes(x.activeSeconds / 60)} from your totals and streaks.')) {
                                await repo.deleteSession(x.id);
                              }
                            },
                          ),
                        ),
                    ]),
            ),
          ]),
        );
      },
    );
  }
}
