# Sync design

Local SQLite is authoritative. Cloud sync is optional and never blocks the UI.

## Platform choice

Native Firestore SDKs are not available for Windows, so `FirebaseRestStore` talks to **Firebase Auth (Identity Toolkit)** and **Firestore** over HTTPS REST using the signed-in user's ID token. The sync engine depends only on the `RemoteStore` interface, so a native SDK adapter can replace it on mobile without touching the engine. No admin credentials are ever in the client; only the public web API key and project ID are passed with `--dart-define`.

## Write path

1. A local change commits to SQLite **together with** its `sync_outbox` row (one transaction).
2. `SyncService.syncNow()` (on app start, on connectivity change, every 2 minutes, or manually) pushes due operations in creation order.
3. Writes are `PATCH users/{uid}/{table}/{id}` with the full document — an idempotent upsert, so duplicates are harmless. Deletes remove the document and write `users/{uid}/tombstones/{table}_{id}`.
4. The outbox row is deleted **only after** the remote confirms.
5. On failure: `attempts++`, `last_error` stored, `next_retry_at = now + min(30 min, 5s·2^attempts)`. Non-transient errors (auth/rules) and ≥8 attempts become `failed` until the user taps *Retry*. Pending work survives crashes because it lives in SQLite.

## Read path

`pullSince(last_pull)` queries each collection by `updated_at > last_pull` plus tombstones. Per remote document:

| Situation | Action |
|---|---|
| Id is in local `deletion_tombstones` | skip (deletion wins) |
| Not present locally | insert |
| Present, remote older/equal | ignore |
| Present, remote newer, **no** unsent local change | take remote |
| Present, remote newer, **unsent local change** | record a **conflict**; local copy is kept |
| Remote tombstone, no pending local change | delete locally |

`last_pull` is set to start-of-pull minus 60 s to tolerate clock skew (re-applying a document is idempotent). Client clocks are not trusted for conflict *detection* — a row is only auto-replaced when there is no unsent local edit.

## Conflict resolution

Conflicts are stored in `sync_metadata` and shown in **Settings → Account & cloud sync → Resolve conflicts** with both versions' edit times: *Keep this device* (re-queued with a fresh timestamp) or *Use cloud version* (applied and the local pending op dropped). Nothing is resolved silently.

## First sign-in on a device with data

The user chooses: **Merge** (queue every local record for upload, pull cloud records, nothing overwritten), **Back up first, then merge**, or **Keep local-only** (sync disabled for this device).

## Status

`Local only · Sign-in required · Offline · Syncing · Synced · N pending · Sync failed`, with last sync time, pending/failed counts, last error, *Sync now* and *Retry failed*. Connectivity is only a hint; real failures come from the requests.

## Security

`firestore.rules` restrict reads/writes to `users/{auth.uid}/…`, allow only known collections, require `data.id == docId`, bound document size, and deny everything else. **Emulator-based rule tests are not yet written** (see README limitations). Auth tokens are persisted in the local DB, not the OS keychain.

## Signing out

Never deletes SQLite data. Pending operations stay queued and upload on the next sign-in; the sign-out dialog states how many are pending.
