# Architecture

Layered, local-first:

```
ui (screens · flows · widgets)
   ↓ Riverpod providers
core/providers  →  core/services (Repository, analysers, backup, sync)
   ↓
SQLite (AppDatabase)  ──outbox──▶  SyncService ──▶ RemoteStore (Firebase REST) [optional]
```

SQLite is the **only source of truth**. Firebase is a replica; no screen waits for the network.

## Folders (mirrors the other AAIBUZZ Flutter projects)

| Path | Responsibility |
|---|---|
| `core/colors`, `core/theme` | Design tokens (palette, gradients, radii) and `ThemeData`. |
| `core/models` | Typed models with `fromMap`/`toMap`; no Flutter imports. |
| `core/services` | All business logic. `app_database.dart` owns the connection and the DAO (`upsert`, `delete`, `transaction`); `schema.dart` holds ordered migrations. `repository.dart` + `*_service.dart` expose typed access as extensions on `Repository`, grouped by domain. |
| `core/services/{goal_analyzer, schedule_generator, coach_service, streak_engine, …}` | Pure Dart, deterministic, unit-tested; operate on an immutable `Snapshot`. |
| `core/providers` | Riverpod wiring: DB/repository, settings, sync, and the `snapshotProvider` that reloads when data changes. |
| `ui/screens` | One file per page. `ui/flows` hold form/dialog flows, `ui/widgets` reusable pieces, `ui/widgets/charts` chart widgets. |
| `ui/routes` | `go_router` shell route; every page is inside `AdaptiveShell`. |

## Data flow for a write

1. UI validates input (form validators).
2. `Repository` calls `AppDatabase.upsert` — one SQLite transaction writes the row **and** the `sync_outbox` entry (and tombstones for deletes).
3. `AppDatabase.changes` emits → `changeProvider` → `snapshotProvider` and other providers reload → UI updates immediately.
4. `SyncService` (if signed in and enabled) pushes pending operations later and marks them done only after the remote confirms.

## Key rules enforced in code

- No SQL or Firebase calls inside widgets.
- Derived numbers (hours, streaks, forecasts, achievements) are recomputed from records; stale caches are never authoritative.
- Estimates never invent data: with no effort source the analyser returns `needsEstimate`.
- Schedules never exceed the user's availability and never delete completed activities.
- Destructive actions explain what is preserved before they run.

## Intelligence (all offline)

`Snapshot` → `GoalAnalyzer.analyze` picks the most trustworthy effort source (your remaining estimate → open milestones/topics → total minus logged → similar completed goals), applies a damped personal calibration (clamped 0.8–1.6, weighted `n/(n+3)`), shares capacity between competing deadline goals by priority, blends planned capacity with 28-day demonstrated pace, and classifies feasibility from `effort ÷ capacity`. These are forecasts, not probabilities.
