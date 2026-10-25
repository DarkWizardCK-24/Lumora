import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/enums.dart';
import '../services/ambient_player.dart';
import '../services/pomodoro.dart';
import '../services/repository.dart';
import '../utils/date_format.dart';
import 'app_providers.dart';
import 'settings_provider.dart';

final ambientPlayerProvider = Provider<AmbientPlayer>((ref) {
  final p = AmbientPlayer();
  ref.onDispose(p.dispose);
  return p;
});

/// What the focus screen shows, plus a counter the UI watches to announce phase changes.
class FocusState {
  const FocusState({this.pomodoro, this.changes = 0, this.lastChangeToBreak = false});
  final Pomodoro? pomodoro;
  final int changes;
  final bool lastChangeToBreak;
  bool get running => pomodoro != null;
}

/// Runs the Pomodoro cycle on top of a normal study session. Work phases count as study
/// time; breaks pause the session so they never inflate the totals. Survives leaving the screen.
class FocusNotifier extends Notifier<FocusState> {
  Timer? _timer;

  @override
  FocusState build() {
    ref.onDispose(() => _timer?.cancel());
    return const FocusState();
  }

  Repository get _repo => ref.read(repoProvider);

  /// Starts a new focus session, or adopts one that is already running.
  Future<void> begin({String? subjectId, String? topicId, String? goalId, SessionType type = SessionType.learning}) async {
    final settings = ref.read(settingsProvider);
    final existing = await _repo.activeSession();
    final session = existing ?? await _repo.startSession(subjectId: subjectId, topicId: topicId, goalId: goalId, type: type);
    final now = nowMs();
    var p = Pomodoro(workMin: settings.focusWorkMin, breakMin: settings.focusBreakMin, phaseStartMs: now);
    // An adopted session that is already paused starts on a frozen clock.
    if (session.status == SessionStatus.paused) p = p.pause(now);
    state = FocusState(pomodoro: p);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Pause or resume the current work phase and the study session together.
  Future<void> togglePause() async {
    final p = state.pomodoro;
    final s = await _repo.activeSession();
    if (p == null || s == null || p.onBreak) return;
    final now = nowMs();
    if (p.paused) {
      await _repo.resumeSession(s);
      _set(p.resume(now));
    } else {
      await _repo.pauseSession(s);
      _set(p.pause(now));
    }
  }

  /// Ends the break early and starts the next focus block.
  Future<void> skipBreak() async {
    final p = state.pomodoro;
    if (p == null || !p.onBreak) return;
    await _endBreak(p);
  }

  /// Call after the session has been saved or discarded.
  void end() {
    _timer?.cancel();
    _timer = null;
    state = const FocusState();
    ref.read(ambientPlayerProvider).stop();
  }

  void _set(Pomodoro p, {bool announce = false}) => state = FocusState(
      pomodoro: p,
      changes: state.changes + (announce ? 1 : 0),
      lastChangeToBreak: announce ? p.onBreak : state.lastChangeToBreak);

  Future<void> _tick() async {
    final p = state.pomodoro;
    if (p == null) return;
    // The session may have been finished elsewhere (e.g. from the sessions page).
    if (await _repo.activeSession() == null) return end();
    final now = nowMs();
    if (!p.phaseOver(now)) return;
    if (p.onBreak) {
      await _endBreak(p);
    } else {
      final s = await _repo.activeSession();
      if (s != null) await _repo.pauseSession(s);
      _set(p.advance(now), announce: true);
      _alert();
    }
  }

  Future<void> _endBreak(Pomodoro p) async {
    final s = await _repo.activeSession();
    if (s != null) await _repo.resumeSession(s);
    _set(p.advance(nowMs()), announce: true);
    _alert();
  }

  void _alert() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
  }
}

final focusProvider = NotifierProvider<FocusNotifier, FocusState>(FocusNotifier.new);
