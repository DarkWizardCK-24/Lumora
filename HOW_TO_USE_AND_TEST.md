# Lumora — How to Run, Use and Test

A practical guide for running Lumora locally, trying every feature by hand, and running the automated tests.
For architecture see `ARCHITECTURE.md`; for the automated-test inventory see `TESTING.md`.

---

## 1. Prerequisites

| Need | Notes |
|---|---|
| Flutter SDK | Dart `^3.13.5` (see `pubspec.yaml`). Check with `flutter --version`. |
| Windows desktop toolchain | Visual Studio with the "Desktop development with C++" workload. Verify with `flutter doctor`. |
| Android / iOS (optional) | Not verified yet (Android licences must be accepted: `flutter doctor --android-licenses`). |
| Firebase (optional) | Only for cloud sync. The app is fully usable offline without it. |

```powershell
cd C:\Users\katar\Desktop\Projects\Flutter\lumora
flutter pub get
```

---

## 2. Run the app

```powershell
flutter run -d windows          # desktop (best-tested)
flutter run -d chrome           # not a supported target (uses SQLite + FFI); prefer windows
flutter run -d <android-id>     # `flutter devices` to list
```

On launch you see the account screen (choose account / sign in / sign up). Accounts are offline: stored in `lumora_accounts.db` in the app support folder. Each account has its own data database, **encrypted at rest** (AES-256-GCM) as `<name>.db.enc`; it is decrypted only while you are signed in and re-encrypted on sign out or window close. You must enter your password at every launch.

- **Recovery key:** shown once at sign up. "Forgot password?" on the sign-in screen resets the password with it; data stays readable. Settings → Local account can issue a new key.
- **Lockout:** 5 wrong passwords lock the account for 30 s, doubling on each further failure (max 15 min).
- **Profile picture / switch account:** set the picture in Settings → Local account; "Switch account / sign out" returns to the chooser.
- The first account created on an existing install adopts the old `lumora.db` and encrypts it.
- If the app is killed, a plaintext working copy may remain until the next sign-in/sign-out re-encrypts it.

Setting `LUMORA_DB` or `LUMORA_SEED_DEMO` below skips the login screen (developer shortcut).

### Developer environment variables (Windows only)

Set these in the same PowerShell session before `flutter run`:

| Variable | Effect |
|---|---|
| `LUMORA_SEED_DEMO=1` | Fills an **empty** database with sample subjects, goals, sessions, notes, etc. Easiest way to explore. |
| `LUMORA_DB=<path>` | Use a specific database file (keeps test data apart from your real data). |
| `LUMORA_WINDOW=390x780` | Opens the window at a given size (try phone width to see the mobile layout). |
| `LUMORA_ROUTE=/analysis` | Opens straight on a page. Routes: `/`, `/goals`, `/subjects`, `/sessions`, `/coding`, `/flashcards`, `/notes`, `/calendar`, `/milestones`, `/analysis`, `/insights`, `/analytics`, `/review`, `/settings`, `/more`, `/focus`. |

Example — a throwaway demo database at phone size:

```powershell
$env:LUMORA_SEED_DEMO = '1'
$env:LUMORA_DB        = "$env:TEMP\lumora-try.db"
$env:LUMORA_WINDOW    = '390x780'
flutter run -d windows
```

Delete the `.db` file (and `-wal`/`-shm` siblings) to reset. Clear the variables afterwards:
`Remove-Item Env:LUMORA_SEED_DEMO, Env:LUMORA_DB, Env:LUMORA_WINDOW`.

### Optional: enable cloud sync

Pass the public Firebase web config at build time:

```powershell
flutter run -d windows `
  --dart-define=FIREBASE_API_KEY=<web-api-key> `
  --dart-define=FIREBASE_PROJECT_ID=<project-id>
```

Without these, Settings → Account shows sync as not configured and the app stays local-only.
Deploy `firestore.rules` to the project first. See `SYNC_DESIGN.md`.

---

## 3. Using the app (quick tour)

Desktop has a sidebar; mobile (narrow window) has bottom tabs **Home · Learning · Planner · Insights · More**.

| Goal | How |
|---|---|
| Create a subject | Subjects → add; optionally pick a starter template (Python, DSA, SQL, …). |
| Create a goal | My Learning (Goals) → add; set subject, deadline, estimated effort, priority. |
| Log study time | Start a timer from Sessions or Focus (Start / Pause / Resume / Stop / Cancel), or add a manual backdated session. |
| Practise coding | Coding → add a problem (platform, difficulty, result, time, attempts); failed ones enter the revision queue. |
| Flashcards | Flashcards → add cards; Review uses spaced repetition (SM-2). In review: `Space`/`Enter` flips, `1`–`4` grades. |
| Notes | Notes → new note; autosaves, `Ctrl+S` saves now; favourite, archive, tag, search. |
| Plan | Calendar → month / week / day / agenda; generate a plan for a goal (preview first), then complete / skip / move blocks. |
| Check feasibility | Smart Analysis → optimistic / realistic / conservative finish dates, risks, alternatives. |
| Review progress | Insights, Analytics (filters) and Weekly Review. |
| Back up | Settings → Backup: export JSON, preview before restore, export CSV / PDF. |

Desktop shortcuts: `Ctrl+K` global search, `Ctrl+N` quick add, `Space` pause/resume and `Esc` leave in Focus mode.

---

## 4. Manual test checklist

Start from an **empty** database (no `LUMORA_SEED_DEMO`) for the first pass, then repeat key items with demo data.

### 4.0 Local login & security
- [ ] Fresh install opens on Create account; weak password / bad email / mismatched confirm are rejected.
- [ ] After sign up a recovery key dialog appears; Continue stays disabled until the box is ticked.
- [ ] Restart the app: login is required again. `lumora_*.db` plaintext is gone from the app support folder, only `.db.enc` remains (while signed out).
- [ ] 5 wrong passwords lock the sign-in button with a countdown; the right password is refused until it expires.
- [ ] Forgot password → email + recovery key + new password works, shows a new key, data is intact. A wrong key is rejected.
- [ ] Two accounts: chooser lists both with pictures; neither sees the other's data.
- [ ] Settings → add/remove picture; change password; new recovery key; delete account (asks for password).

### 4.1 First run & CRUD
- [ ] App opens to an empty Dashboard with no fake numbers.
- [ ] Create a subject, goal, milestone, topic, note, coding problem, flashcard — each appears immediately.
- [ ] Edit and delete each; deleting a subject/goal unlinks (does not crash) related items.
- [ ] Close and reopen the app: everything persists.

### 4.2 Timer
- [ ] Start → pause → resume → stop: duration excludes the paused time.
- [ ] Start a timer, **kill the app**, reopen: the session is recovered, duration comes from saved timestamps.
- [ ] Cancel discards the session. Manual backdated session shows on the right day.

### 4.3 Planning & analysis
- [ ] Goal with no estimate → Analysis asks for an estimate instead of guessing.
- [ ] Goal with a tight deadline → flagged at risk, with alternatives.
- [ ] Generate a plan → preview shows study/practice/revision blocks within your availability; completed work is kept on regenerate.
- [ ] Move / skip / complete a planned block: planned time and actual time stay separate.

### 4.4 Streaks & analytics
- [ ] A session ≥ the minimum minutes extends the streak; today pending does not break it.
- [ ] Add a backdated session → streak recalculates; delete it → recalculates again.
- [ ] Analytics filters (range / subject / goal / type) change the charts.

### 4.5 Backup
- [ ] Export JSON, then "restore" it: preview shows counts before applying.
- [ ] Try restoring a non-Lumora/invalid file: rejected with a message.
- [ ] Delete-all keeps your preferences (theme etc.).

### 4.6 Responsive & appearance
- [ ] Resize the window from wide to ~320 px: no overflow stripes, layout switches to bottom nav.
- [ ] Settings → Appearance: light / dark / system and palette changes apply everywhere.
- [ ] Increase Windows text scaling: still no overflow.

### 4.7 Sync (only with Firebase configured)
- [ ] Sign up / sign in from Settings → Account.
- [ ] Create data offline → reconnect → it syncs once (no duplicates).
- [ ] Delete on device A → disappears on device B.
- [ ] Edit the same item on two devices → conflict-resolution screen appears.

---

## 5. Automated tests

```powershell
flutter analyze        # static analysis / lints
flutter test           # all suites
```

Run one suite or one test:

```powershell
flutter test test/logic_test.dart
flutter test test/database_sync_test.dart
flutter test test/responsive_test.dart
flutter test test/new_features_test.dart
flutter test test/logic_test.dart --plain-name "streak"
```

| Suite | Covers |
|---|---|
| `logic_test.dart` | Duration maths, streaks, goal analysis, schedule generation, coach tips. |
| `database_sync_test.dart` | Migrations, CRUD, timers, sync outbox/retry/conflicts, backup preview (in-memory SQLite + fake remote). |
| `responsive_test.dart` | Every route × 9 widths × text scales × empty/seeded — no overflow. |
| `auth_test.dart` | Sign up/in, lockout and escalation, recovery-key reset, encrypted data file round trip, per-user files, avatar, legacy adoption, change password, new recovery key, delete account. |
| `new_features_test.dart` | Tests for the newer features (flashcards, focus, etc.). |

No device, emulator or network is needed. Not covered yet: live Firebase / rules emulator, Android/iOS runs, full file-based restore round trip (see `TESTING.md`).

---

## 6. Build & screenshots

```powershell
flutter build windows --debug
powershell -File tool\capture_screenshots.ps1    # regenerates docs\screenshots (assumes 125% display scaling)
flutter build windows --release                  # output: build\windows\x64\runner\Release\lumora.exe
```

---

## 7. Troubleshooting

| Symptom | Fix |
|---|---|
| `flutter pub get` fails on SDK constraint | Upgrade Flutter (`flutter upgrade`); project needs Dart ≥ 3.13.5. |
| Windows build errors | Run `flutter doctor`; install the Visual Studio C++ desktop workload. |
| Demo data doesn't appear | `LUMORA_SEED_DEMO` only seeds an **empty** DB — point `LUMORA_DB` at a new file. |
| Env variables seem ignored | They must be set in the same shell that runs `flutter run`, and only apply on Windows desktop. |
| Sync says "not configured" | Rebuild with both `--dart-define` Firebase values. |
| Want a clean slate | Close the app, delete the SQLite file (or use Settings → delete all data). |
