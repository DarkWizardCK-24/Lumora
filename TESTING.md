# Testing

```bash
flutter analyze
flutter test
```

| Suite | File | Covers |
|---|---|---|
| Logic | `test/logic_test.dart` | Active-duration maths with pauses; streak rules (pending today, min minutes, solved problems); no double counting of linked practice; goal analysis (needs-estimate, on track, infeasible, passed/completed, manual progress, time ≠ mastery, damped calibration); schedule generation (availability cap, unscheduled gap reported, completed work kept, topics first); coach tips (explanations, dismissal fingerprint). |
| Database & sync | `test/database_sync_test.dart` | Migrations; foreign keys; CRUD with UUIDs; unlink-on-delete rules; transaction rollback; note search; timer idempotency & recovery; outbox + tombstone transactions; push failure/backoff/retry/failed state; exactly-once delivery after reconnect; delete propagation; pull insert / tombstone skip / conflict detection & resolution; initial merge; backup preview, invalid-file rejection, delete-all keeps preferences. Uses an in-memory SQLite (`sqflite_common_ffi`) and a fake `RemoteStore`. |
| Responsive | `test/responsive_test.dart` | All routes × 9 widths × {1×, 2×} text × {empty, seeded} — no overflow exceptions. |

## Not covered (yet)

- A full file-based restore round trip (needs `path_provider`, so only preview/validation is unit-tested).
- Live Firebase and emulator-based security-rule tests.
- Android/iOS device runs, golden images and integration tests on a real device.
- Native keyboard/IME behaviour (verified only via bottom-sheet insets in layout).

## Manual verification done

Windows debug build launched and captured at desktop and phone-sized windows (`tool/capture_screenshots.ps1`) with the demo dataset.
