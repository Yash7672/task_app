# PYLO Strict Focus Mode - Implementation Plan

## Overview

Implement a Strong/Strict Focus Mode in PYLO with two levels (Normal + Strict), PIN-protected exit, Android Lock Task integration, and robust timer persistence.

---

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| State management | Extend existing Riverpod `FocusNotifier` | Consistent with codebase patterns |
| Timer persistence | SharedPreferences timestamps (existing pattern) | Already used by `FocusService`, survives kills |
| PIN verification | Reuse `PinService.verifyPin()` | Existing secure implementation |
| Android restrictions | MethodChannel → `ActivityManager.startLockTask()` | Official Android API, no hacks |
| Navigation blocking | `PopScope` + replace navigator stack | Flutter-supported, works on all platforms |
| Mode storage | SharedPreferences (`focus_strict_mode`) | Simple preference, no DB schema change |

---

## Files to Create (6 new files)

### 1. `lib/features/focus/screens/focus_pin_dialog.dart`
- Reusable PIN verification dialog for ending strict focus
- Uses existing `PinPad` widget internally
- Returns `true`/`false` via `Navigator.pop`
- Shows error text for wrong PIN, lockout state

### 2. `lib/features/focus/screens/focus_active_screen.dart`
- Dedicated fullscreen screen for active focus session (both modes)
- `PopScope(canPop: false)` to block back navigation
- In Strict mode: shows warning toast on back press attempt
- In Normal mode: shows confirmation dialog on back press
- Contains timer, label, pause/end buttons
- End Focus → confirmation → (Strict: PIN dialog) → stop session

### 3. `lib/core/services/focus_channel.dart`
- Dart-side MethodChannel wrapper (`pylo/focus`)
- Methods: `enterLockTask()`, `exitLockTask()`, `isLockTaskAvailable()`
- Platform-aware: no-op on web/desktop/iOS
- Error handling with fallback (app works even if Lock Task fails)

### 4. `android/app/src/main/kotlin/com/example/task_app/FocusTaskService.kt` (optional)
- Not needed - `startLockTask()` is called directly on Activity
- MainActivity handles the MethodChannel calls directly

### 5. No additional native files needed
- MainActivity.kt will be extended inline with MethodChannel handling

---

## Files to Modify (8 existing files)

### 1. `lib/models/focus_session_model.dart`
- Add `FocusMode` enum: `normal`, `strict`
- Add `mode` field to `FocusSession` (default: `normal`)
- Update `toMap()` / `fromMap()` to include `mode`
- **No DB migration needed** — `fromMap` defaults to `normal` if column missing

### 2. `lib/services/focus/focus_service.dart`
- Add `isStrictMode` getter from SharedPreferences
- Add `setStrictMode(bool)` setter
- Persist `focus_mode` key in SharedPreferences alongside existing keys
- `startFocus()`: accept `FocusMode` parameter, save to prefs
- `loadActiveSession()`: restore mode from prefs
- Add `enterLockTask()` / `exitLockTask()` calls via `FocusChannel`
- `_finalize()`: exit Lock Task mode, cancel notifications

### 3. `lib/providers/focus_provider.dart`
- Add `isStrictMode` to `FocusState`
- Add `toggleStrictMode()` / `setStrictMode()` to `FocusNotifier`
- Add `verifyPinForExit(String pin)` method
- Add `_isPaused` state for pause/resume functionality
- Add `pauseSession()` / `resumeSession()` methods
- On restore: load strict mode preference, enter Lock Task if strict

### 4. `lib/features/focus/screens/focus_screen.dart`
- Add Normal/Strict mode toggle (two large cards)
- Update preset durations: 15, 25, 30, 45, 60, Custom
- When starting: pass mode to provider
- When active: navigate to `FocusActiveScreen` instead of inline display
- Keep history sheet as-is

### 5. `lib/features/focus/widgets/focus_timer.dart`
- Add `isStrictMode` parameter
- In strict mode: show lock icon instead of fire emoji
- Change label from "FOCUS MODE" to "STRICT FOCUS" in strict mode
- Keep existing circular progress and countdown logic

### 6. `lib/navigation/app_navigation.dart`
- Wrap with `PopScope` that checks focus state
- When focus is active: `canPop: false`, prevent bottom nav interaction
- Optionally hide bottom nav bar when focus is active

### 7. `lib/features/auth/screens/app_lock_screen.dart`
- In `AppLockGate.build()`: if focus is active, redirect to `FocusActiveScreen`
- Prevents navigating around PYLO during focus session
- Only applies when focus session exists in provider state

### 8. `android/app/src/main/kotlin/com/example/task_app/MainActivity.kt`
- Add `MethodChannel` registration for `pylo/focus`
- Implement `startLockTask()` / `stopLockTask()` using `ActivityManager`
- Handle `SecurityException` gracefully (return false)
- Check `isInLockTaskMode()` for status queries

### 9. `android/app/src/main/AndroidManifest.xml`
- Add `android:taskAffinity=""` to main activity (already present ✓)
- No additional permissions needed for `startLockTask()` on standard apps
- Add comment explaining Lock Task limitations for non-device-owner apps

---

## Detailed Implementation Flow

### Start Focus Flow

```
User opens Focus Screen
    ↓
Selects Normal or Strict mode (two cards)
    ↓
Selects duration (15/25/30/45/60/Custom)
    ↓
Optionally selects task or types label
    ↓
Taps [Start Focus]
    ↓
FocusNotifier.startFocus(mode: selected)
    ↓
FocusService.startFocus() saves to SharedPreferences
    ↓
If Strict: FocusChannel.enterLockTask() (Android only)
    ↓
Navigator.pushReplacement → FocusActiveScreen
    ↓
Timer starts (timestamp-based countdown)
    ↓
Ongoing notification shown
    ↓
Completion notification scheduled
```

### Active Focus Screen (Strict Mode)

```
┌─────────────────────────┐
│     🔒                  │  ← No back button
│                         │
│    STRICT FOCUS         │
│                         │
│      24:32              │  ← Countdown
│                         │
│   Study DAA             │  ← Current task/label
│                         │
│     [End Focus]         │  ← Single button
│                         │
└─────────────────────────┘

Back press → Toast: "Focus is active. Use End Focus to stop."
```

### End Focus Flow (Strict + PIN)

```
User taps [End Focus]
    ↓
Show confirmation dialog:
"End Focus?"
[Cancel]  [End Focus]
    ↓
User taps [End Focus]
    ↓
Show PIN dialog (focus_pin_dialog.dart)
    ↓
User enters 4-digit PIN
    ↓
PinService.verifyPin(pin)
    ↓
Correct → FocusNotifier.stopSession()
        → FocusChannel.exitLockTask()
        → Cancel notifications
        → Navigator.pop() → back to normal PYLO
    ↓
Wrong → Show error in dialog
      → Focus continues
      → Dialog stays open for retry
```

### App Background/Resume

```
App paused (backgrounded)
    ↓
FocusService timestamps are absolute (endTime stored as ms)
    ↓
Timer continues logically even when app is killed
    ↓
App resumed / reopened
    ↓
FocusNotifier._restore() called
    ↓
loadActiveSession() reads from SharedPreferences
    ↓
Computes remaining = endTime - now
    ↓
If remaining > 0: restore active session, navigate to FocusActiveScreen
If remaining <= 0: auto-complete session, return to normal
```

### App Killed Recovery

```
Android kills PYLO process
    ↓
SharedPreferences data survives (focus_label, focus_start_ms, focus_end_ms)
    ↓
User reopens PYLO
    ↓
FocusNotifier._restore() → loadActiveSession()
    ↓
Session restored with correct remaining time
    ↓
If strict mode was active: re-enter Lock Task
    ↓
User returns to FocusActiveScreen
```

---

## Native Android Implementation (MainActivity.kt)

```kotlin
// MethodChannel: pylo/focus
// Methods:
//   "enterLockTask" → ActivityManager.startLockTask()
//   "exitLockTask"  → ActivityManager.stopLockTask()
//   "isLockTaskActive" → ActivityManager.isInLockTaskMode()

// IMPORTANT LIMITATIONS:
// - startLockTask() on non-device-owner apps: shows a persistent
//   notification and may allow exit via long-press Home/Overview
// - On Android 12+: system may show "Exit" option in recents
// - True kiosk mode requires Device Owner / Profile Owner provisioning
// - The app still works normally on personal phones
```

---

## Notification Strategy

| Event | Notification | ID |
|-------|-------------|-----|
| Focus started | "Focus session started" (optional, immediate) | 910003 |
| Focus ongoing | Updated remaining time (existing) | 910001 |
| Focus complete | "🎉 Focus session complete!" | 910002 |
| Early stop | Cancel 910002, show "Focus ended" (optional) | - |

No duplicate notifications. Completion notification cancelled if session ended early.

---

## Performance Considerations

- **Timer**: Single `Timer.periodic(1s)` in `FocusNotifier`, not in UI widgets
- **Timestamp-based**: `ActiveFocus.remaining` computes from stored `endTime`, no drift
- **No DB queries during focus**: All active state in SharedPreferences (memory + prefs)
- **Single rebuild**: `state = state.copyWithState(active: session)` triggers minimal widget rebuilds
- **No background services**: Timer runs only when app is in foreground
- **Lock Task**: Single native call on start/stop, no polling

---

## Testing Checklist

1. ✅ Start 1-minute Normal Focus → countdown works
2. ✅ Start 1-minute Strict Focus → countdown works
3. ✅ Back button in Normal mode → confirmation dialog
4. ✅ Back button in Strict mode → warning toast, no exit
5. ✅ Android back gesture → same as back button
6. ✅ End Focus in Normal → confirmation only
7. ✅ End Focus in Strict → confirmation + PIN
8. ✅ Wrong PIN → error, focus continues
9. ✅ Correct PIN → focus ends, returns to normal
10. ✅ App background → timer pauses logically
11. ✅ App resume → correct remaining time shown
12. ✅ Screen lock → timer preserved
13. ✅ App reopen → focus session restored
14. ✅ Timer completion → auto-ends, notification shown
15. ✅ Notification arrives on completion
16. ✅ Incoming phone call → not blocked
17. ✅ PYLO task reminder → not blocked
18. ✅ Birthday notification → not blocked
19. ✅ Habit notification → not blocked
20. ✅ Multiple sequential focus sessions → no state leaks
21. ✅ Force-close during focus → session restored on reopen
22. ✅ Strict mode Lock Task → Android restriction active (on supported devices)
23. ✅ Pause/Resume → timer correctly paused and resumed
