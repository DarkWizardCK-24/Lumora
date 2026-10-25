import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../models/study_session.dart';
import 'settings_provider.dart';
import '../services/achievement_engine.dart';
import '../services/app_database.dart';
import '../services/backup_service.dart';
import '../services/coach_service.dart';
import '../services/repository.dart';
import '../services/snapshot.dart';
import '../services/xp_engine.dart';

final dbProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('override in main'));

final repoProvider = Provider<Repository>((ref) => Repository(ref.watch(dbProvider)));

final backupProvider = Provider<BackupService>((ref) => BackupService(ref.watch(dbProvider)));

/// Emits whenever any local data changes; data providers watch this.
final changeProvider = StreamProvider<int>((ref) async* {
  var n = 0;
  yield n;
  await for (final _ in ref.watch(dbProvider).changes) {
    yield ++n;
  }
});

/// Everything the analysers need, reloaded when any data changes.
final snapshotProvider = FutureProvider<Snapshot>((ref) async {
  ref.watch(changeProvider);
  final repo = ref.watch(repoProvider);
  final settings = ref.watch(settingsProvider);
  return Snapshot(
    goals: await repo.goals(),
    milestones: await repo.milestones(),
    sessions: await repo.sessions(),
    activities: await repo.activities(),
    problems: await repo.problems(),
    topics: await repo.topics(),
    subjects: await repo.subjects(),
    cards: await repo.flashcards(),
    cardReviews: await repo.cardReviews(),
    attempts: await repo.attempts(),
    availability: await repo.availability(),
    minQualifyingMinutes: settings.minQualifyingMinutes,
    dailyTargetMinutes: settings.dailyTargetMinutes,
    studyHour: settings.studyHour,
    streakFreezeEnabled: settings.streakFreeze,
  );
});

final tipsProvider = FutureProvider<List<Tip>>((ref) async {
  final s = await ref.watch(snapshotProvider.future);
  final dismissed = await ref.watch(repoProvider).dismissedTips();
  return CoachService.tips(s, dismissed);
});

final activeSessionProvider = FutureProvider<StudySessionHolder?>((ref) async {
  ref.watch(changeProvider);
  final repo = ref.watch(repoProvider);
  final s = await repo.activeSession();
  return s == null ? null : StudySessionHolder(s, await repo.pauses(s.id));
});

class StudySessionHolder {
  StudySessionHolder(this.session, this.pauses);
  final StudySession session;
  final List<Pause> pauses;
}

/// Awards achievements from real records. `award` is idempotent so reruns never duplicate.
final achievementsProvider = FutureProvider<Map<String, int>>((ref) async {
  final s = await ref.watch(snapshotProvider.future);
  final repo = ref.watch(repoProvider);
  for (final code in AchievementEngine.earned(s)) {
    await repo.award(code);
  }
  return repo.achievements();
});

final notesProvider = FutureProvider.family<List<Note>, String>((ref, query) async {
  ref.watch(changeProvider);
  return ref.watch(repoProvider).notes(query: query);
});

/// XP and level, or null until both the data and the achievements have loaded
/// (so a half-loaded state can never look like a level change).
final xpProvider = Provider<XpInfo?>((ref) {
  final s = ref.watch(snapshotProvider).value;
  final ach = ref.watch(achievementsProvider).value;
  if (s == null || ach == null) return null;
  return XpEngine.compute(s, achievements: ach.length);
});
