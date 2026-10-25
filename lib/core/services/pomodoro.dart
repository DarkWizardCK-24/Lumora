/// Pure Pomodoro timing. All times are epoch milliseconds so it is trivial to test.
class Pomodoro {
  const Pomodoro({
    this.workMin = 25,
    this.breakMin = 5,
    this.cycle = 1,
    this.onBreak = false,
    required this.phaseStartMs,
    this.pausedAtMs,
  });

  final int workMin, breakMin, cycle;
  final bool onBreak;
  final int phaseStartMs;

  /// When the user paused the current phase; the clock is frozen while set.
  final int? pausedAtMs;

  /// Every fourth break is a long one (three times the normal length, at most 30 min).
  static const longBreakEvery = 4;

  bool get isLongBreak => onBreak && cycle % longBreakEvery == 0;
  int get breakLenMin => cycle % longBreakEvery == 0 ? (breakMin * 3).clamp(breakMin, 30) : breakMin;
  int get phaseLenSeconds => (onBreak ? breakLenMin : workMin) * 60;
  bool get paused => pausedAtMs != null;

  int elapsedSeconds(int nowMs) {
    final ref = pausedAtMs ?? nowMs;
    final e = (ref - phaseStartMs) ~/ 1000;
    return e < 0 ? 0 : e;
  }

  int remainingSeconds(int nowMs) => (phaseLenSeconds - elapsedSeconds(nowMs)).clamp(0, phaseLenSeconds);

  double progress(int nowMs) => phaseLenSeconds == 0 ? 0 : elapsedSeconds(nowMs) / phaseLenSeconds;

  bool phaseOver(int nowMs) => !paused && remainingSeconds(nowMs) <= 0;

  Pomodoro pause(int nowMs) => paused ? this : _copy(pausedAtMs: nowMs);

  /// Resuming shifts the phase start forward by the time spent paused.
  Pomodoro resume(int nowMs) =>
      paused ? _copy(phaseStartMs: phaseStartMs + (nowMs - pausedAtMs!), clearPause: true) : this;

  /// Work -> break, or break -> next work cycle.
  Pomodoro advance(int nowMs) => onBreak
      ? Pomodoro(workMin: workMin, breakMin: breakMin, cycle: cycle + 1, phaseStartMs: nowMs)
      : Pomodoro(workMin: workMin, breakMin: breakMin, cycle: cycle, onBreak: true, phaseStartMs: nowMs);

  Pomodoro _copy({int? phaseStartMs, int? pausedAtMs, bool clearPause = false}) => Pomodoro(
        workMin: workMin,
        breakMin: breakMin,
        cycle: cycle,
        onBreak: onBreak,
        phaseStartMs: phaseStartMs ?? this.phaseStartMs,
        pausedAtMs: clearPause ? null : (pausedAtMs ?? this.pausedAtMs),
      );
}
