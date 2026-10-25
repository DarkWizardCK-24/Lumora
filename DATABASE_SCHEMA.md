# Database schema

SQLite, schema version **1** (`lib/core/services/schema.dart`). `PRAGMA foreign_keys = ON` at open. Primary keys are UUID v4 text. Instants are UTC epoch **milliseconds**; calendar dates (deadlines, due dates) are `YYYY-MM-DD` text. Migrations are append-only and recorded in `schema_migrations`.

## Learning data (synced)

| Table | Key columns | Notes |
|---|---|---|
| `subjects` | name, icon, color, category, difficulty, target_hours, archived | Deleting cascades to its topics; goals/sessions/notes/problems are kept (`SET NULL`). |
| `topics` | subject_id → subjects (CASCADE), goal_id → goals (SET NULL), estimated_minutes, status, revision_status, prerequisite_id | Linking topics to a goal gives evidence-based progress. |
| `learning_goals` | subject_id, current/target_level, start_date, deadline, estimated_minutes, remaining_minutes, priority, status, manual_progress, criteria | `manual_progress` is never overwritten by calculation. |
| `goal_milestones` | goal_id (CASCADE), due_date, completed_at, estimated_minutes, criteria | |
| `study_sessions` | subject/topic/goal (SET NULL), session_type, started_at, ended_at, active_seconds, status | `running`/`paused` rows are recoverable after a crash. |
| `session_pauses` | session_id (CASCADE), started_at, ended_at | Active time = elapsed − pauses. |
| `scheduled_activities` | goal_id (CASCADE), kind, planned_start/end, planned_minutes, status, generated | Planned time is separate from actual sessions. |
| `coding_problems` | platform, difficulty, result, minutes, attempts, revision_required, next_review, session_id | `session_id` prevents double-counting practice time. |
| `notes` | title, body, subject/topic/goal/session/problem links, tags, favorite, archived | |

All synced tables carry `created_at`, `updated_at` and an integer `version` incremented on every local write.

## Supporting tables (local)

`tags`, `note_tags`, `achievements(code, earned_at)`, `user_preferences(key, value)`, `study_availability(weekday, minutes)`, `coaching_tip_history(tip_key, fingerprint)`, `weekly_reviews`, `schedule_revisions` (audit of applied plans), `schema_migrations`.

## Sync tables

| Table | Purpose |
|---|---|
| `sync_outbox` | id, entity_type, entity_id, op (`upsert`/`delete`), payload JSON, created_at, attempts, last_error, next_retry_at, status (`pending`/`failed`). Written in the same transaction as the change; older pending ops for the same entity collapse into the newest. |
| `deletion_tombstones` | (entity_type, entity_id) → deleted_at. Prevents deleted rows from reappearing on pull. |
| `sync_metadata` | last_pull, last_sync, conflicts JSON, auth session. |

## Indexes

`study_sessions(started_at, goal_id, subject_id)`, `session_pauses(session_id)`, `topics(subject_id)`, `goal_milestones(goal_id)`, `scheduled_activities(planned_start, goal_id)`, `coding_problems(attempted_at)`, `notes(updated_at)`, `sync_outbox(status, next_retry_at)`.

## Tables from the brief that were intentionally not created

`activity_dependencies`, `coding_attempts`, `goal_estimates`, `goal_forecasts`: forecasts and estimates are derived on demand from the records above (stored forecasts would go stale), and per-attempt history is represented by `coding_problems.attempts`. They can be added by a new migration if needed.

## Deletion behaviour

| Delete | Removed | Kept (unlinked) |
|---|---|---|
| Subject | its topics | goals, sessions, notes, problems |
| Goal | milestones, planned activities | sessions, notes, topics |
| Session | its pauses | linked problems |
| Anything synced | row + tombstone + outbox `delete` | — |
