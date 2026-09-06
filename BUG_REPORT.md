# PYLO Production-Readiness QA — Final Bug Report

## A. Executive summary

A two-part code audit of the PYLO Flutter app was performed and every confirmed bug was
fixed at root cause (no UI redesign, no feature removal, **no task data is ever deleted** —
deletes remain soft). The repository now passes the full verification pipeline from a clean
state and produces a release APK.

Part 1 root-caused and fixed the Delete → Undo data-loss race (a serialized mutation queue).
Part 2 broad-audited notifications/recurrence, widgets/birthdays, habits/checklist/calendar,
and state/forms/lock/focus, then re-verified every finding in code before fixing it.

## B. Scope & methodology

1. Delete/Undo audit: reproduced the swiped task failing to come back after undo, traced it to
   interleaved DB writes / state refreshes, and fixed it with a FIFO mutation queue.
2. Four parallel code audits (notifications/recurrence; widgets/birthdays;
   habits/checklist/calendar; state/forms/lock/focus). Subagent reports were treated as
   research only — every finding was personally re-verified against the source before changing code.
3. All fixes verified with `flutter clean && pub get && analyze && test && build apk --release`.

## C. CRITICAL (data loss / corruption) — all fixed

| # | Finding | Fix |
|---|---------|-----|
| C1 | **Delete → Undo race**: swipe-delete + immediate Undo could run concurrently; the restore could be lost (task never returns) and reminders never rescheduled. | `TaskNotifier._mutationQueue` (FIFO) in `lib/providers/task_provider.dart`; **all** mutations are serialized. `restoreTask` returns the restored model and re-arms reminders only from it. Undo button awaits restore. |
| C2 | **Habit snapshot dual-write**: the complete-sheet rebuilt the day snapshot from log items, silently wiping checklist items edited directly in the day-detail sheet. | DOCUMENTED as a design-level limitation (two edit surfaces, one snapshot). Mitigation: manual mark/unmark now re-syncs the snapshot from log items; unmark clears it, so marked/unmarked days always match. |

## D. HIGH — all fixed

| # | Finding | Fix |
|---|---------|-----|
| D1 | Settings "Task reminders" toggle only flipped a stored flag — pending task notifications were never cancelled/rescheduled. | Toggle now calls `cancelAllTaskReminders()` / `rescheduleAllTaskReminders()` (`settings_screen.dart`; `TaskNotifier` in `task_provider.dart`). |
| D2 | Task reminders were never re-armed at startup (only birthdays were) or after a backup import. | Startup re-arm in `main.dart` `_initBackgroundServices`; import re-arm in `_importBackup`. |
| D3 | **Strict-focus lockout trap**: with no PIN set, "End Focus" demanded a PIN that could never be verified — the user could not leave strict mode. | `_endFocus` checks `PinService.hasPin()`; without a PIN it requires only explicit confirmation. |
| D4 | **Lock Task failure was silent**: when pinning failed (device-owner/restrictions), the UI claimed "PYLO is locked" while nothing was pinned. `enterLockTask()` results were ignored. | New `FocusState.lockTaskUnavailable` flag surfaced as an on-screen warning; re-checked after every resume and after `enterLockTask` fails. |
| D5 | **Recurrence drift**: a Jan-31 monthly task recurs Jan 31 → Feb 28 → Mar 28 → … forever (anchor lost); Feb-29 yearly tasks rolled to Mar 1 permanently. | New `repeatMonthday` column (schema **v10**) stores the original day-of-month; monthly/yearly recurrence clamps the *anchor* to each target month (Feb 28 then **Mar 31**); Feb-29 → Feb 28 in non-leap years, Feb 29 in leap years, never Mar 1. Migration v9→v10 backfills anchors from `dueDate`. `regenerate()` carries the anchor. |
| D6 | **Editing a completed task re-armed its reminders** (a done task would start nagging again). | Save path skips scheduling when the edited task was already completed. |
| D7 | **Birthday lead-time drift**: a reminder whose X-days-before date had already passed was pushed +1 year, silently skipping the current cycle. | `scheduleBirthdayReminders` falls back to scheduling on the birthday itself when the lead time is past but the birthday is still ahead. |
| D8 | **Checklist double-tap loss**: rapid toggles wrote the same value twice; `addItem` position used list-length (collision after deletes). | ChecklistNotifier got the same FIFO queue; toggles re-read the row inside the queue; position = current max + 1. |
| D9 | **Add/Edit task**: changing the due date left start/end times on the old date; double-tapping Save wrote duplicates + duplicate reminders. | Date picker re-anchors times onto the new date; `_saving` guard prevents double-save; save path persists `repeatMonthday`. |

## E. MEDIUM — all fixed

| # | Finding | Fix |
|---|---------|-----|
| E1 | `cancelAllForTask` capped at 12 cancellations while scheduling was unbounded → orphaned notifications. | Shared `maxReminders = 12` constant used by both loops; plugin also `ensureInitialized` on cancel paths. |
| E2 | Exact-alarm scheduling failed silently when Android 12+ alarm permission is denied. | All three schedule sites (task, yearly birthday, shared `zonedSchedule`) retry with `inexactAllowWhileIdle`. |
| E3 | Habit streak math used `difference().inDays` on local DateTimes — DST shifts fold two days into one gap. | DST-safe day diff via UTC `(y,m,d)` components; "yesterday" via date arithmetic (`day - 1`). |
| E4 | `bestStreak` was never recomputed down (monotonic "preserve at least previous best") — manual history edits left an inflated all-time streak. | `_recalculateStreaks` now recomputes the true longest run from stored history (deliberate behavior change; verified against existing tests). |
| E5 | `todayTasksProvider` / `upcomingTasksProvider` used `<= 23:59:59.999` inclusive windows. | Day boundaries are now exclusive `[startOfDay, startOfNextDay)`. |
| E6 | Birthday dialog silently defaulted to `2000-01-01` when no date was picked and accepted duplicates. | Date is now required (no bogus default); duplicate (name + month/day) guarded, excluding the entry being edited. |
| E7 | Progress widget rendered "Today's Progress" twice (static XML label + Kotlin-written text). | Kotlin no longer writes the label text. |

## F. LOW — all fixed

| # | Finding | Fix |
|---|---------|-----|
| F1 | "Tomorrow" computed with `add(Duration(days:1))` — wrong across DST. | Date constructor arithmetic (`day + 1`). |
| F2 | App-lock lockout countdown froze after a second lockout right after one ended, and could show a stale "0 s". | `_syncLockout` always starts/stops the ticker correctly and renders "a moment" when ≤ 0. |
| F3 | Test isolation: shared `taskflow.db` caused cross-file residue and Windows file-lock issues. | `DatabaseHelper.testDbPathOverride`; tests use private DB paths. |

Documented / deferred (no code change — noted here for completeness):
- **Notification-ID namespace** (`task.id.hashCode + offset`) is deterministic and capped at 12 per task; birthday IDs already use a separate namespace. Low collision risk; acceptable.
- **Timezone-change day drift**: dates are stored as local-midnight epoch millis; changing the device timezone moves a task into a new day bucket. Requires switching to UTC date keys — deferred (single-timezone app assumption).
- **Focus widget freezes when the app is killed** (HomeWidget countdown needs a live process). Deferred — a background service would contradict the "no per-second background polling" constraint.
- **Boot receiver** only refreshes on `BOOT_COMPLETED`, not `TIME_SET` / `TIMEZONE_CHANGED`. Documented.

## G. TEST RESULTS (clean pipeline)

| Step | Command | Result |
|------|---------|--------|
| Clean | `flutter clean` | OK (8.2 s) |
| Dependencies | `flutter pub get` | OK |
| Static analysis | `flutter analyze` | **No issues found** |
| Tests | `flutter test` | **51 passed, 0 failed** |
| Build | `flutter build apk --release` | **Built `build\app\outputs\flutter-apk\app-release.apk` (61.9 MB)** |

New/extended tests added this pass:
- `test/recurrence_test.dart`: anchored day-31 monthly no-drift (incl. year boundary), anchored Feb-29 yearly leap/non-leap cycle, `regenerate` anchor preservation (4 new).
- `test/habit_history_test.dart`: v9→v10 migration adds `repeatMonthday` and backfills from `dueDate` (1 new).
- `test/undo_repro_test.dart` (5 tests, carried from part 1) plus model/DB round-trip suites.

## H. Not performed / real-device only

The following could not be verified in this environment (no Android device/emulator) and
**must be smoke-tested on hardware**:

1. **Widget rendering/layout** (Progress, Focus, Check-in, Birthdays, countdown tick).
2. **Notification delivery**, the Android 12+ exact-alarm permission flow (should now degrade to
   inexact instead of silently dropping), and re-arm on app restart / backup import.
3. **Lock Task pinning**: real pinning requires a device-owner/DPM setup; on a normal device the new
   on-screen warning ("Device lock is not active…") is the expected behaviour. Verify the warning appears
   and that strict focus otherwise still runs + can be ended (with and without a PIN set).
4. **Fingerprint/Face unlock** prompt (fingerprint only on explicit button tap; no Face ID).
5. Backup import re-arming reminder notifications end-to-end.

Recommended device test matrix: default-strict focus without PIN → end works; strict focus with PIN →
PIN required; birthdays within 1/3/7-day lead times (including one that just passed); Jan-31 monthly task
over Feb/Mar; Feb-29 yearly task across a leap year; "Task reminders" master toggle off/on with pending tasks.