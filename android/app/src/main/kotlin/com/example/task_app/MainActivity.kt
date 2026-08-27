package com.example.task_app

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "pylo/focus"
    private var isLockTaskActive = false
    private var pendingWidgetAction: String? = null
    private var pendingWidgetTaskId: String? = null
    private var pendingWidgetHabitId: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enterLockTask" -> {
                        result.success(enterLockTask())
                    }
                    "exitLockTask" -> {
                        result.success(exitLockTask())
                    }
                    "isLockTaskActive" -> {
                        result.success(isLockTaskActive())
                    }
                    "setLockScreenFlags" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        setLockScreenFlags(enabled)
                        result.success(true)
                    }
                    "getWidgetAction" -> {
                        result.success(mapOf(
                            "action" to pendingWidgetAction,
                            "task_id" to pendingWidgetTaskId,
                            "habit_id" to pendingWidgetHabitId,
                        ))
                    }
                    "clearWidgetAction" -> {
                        pendingWidgetAction = null
                        pendingWidgetTaskId = null
                        pendingWidgetHabitId = null
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // ── Handle widget intent if activity was launched from widget ──
        handleWidgetIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleWidgetIntent(intent)
    }

    private fun handleWidgetIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: return

        when (action) {
            "WIDGET_OPEN_TASK" -> {
                pendingWidgetAction = "open_task"
                pendingWidgetTaskId = intent.getStringExtra("widget_task_id")
                pendingWidgetHabitId = null
            }
            "WIDGET_OPEN_HABITS" -> {
                pendingWidgetAction = "open_habits"
                pendingWidgetHabitId = intent.getStringExtra("widget_habit_id")
                pendingWidgetTaskId = null
            }
            "WIDGET_OPEN_DASHBOARD" -> {
                pendingWidgetAction = "open_dashboard"
                pendingWidgetTaskId = null
                pendingWidgetHabitId = null
            }
            "WIDGET_ADD_TASK" -> {
                pendingWidgetAction = "add_task"
                pendingWidgetTaskId = null
                pendingWidgetHabitId = null
            }
        }
    }

    private fun enterLockTask(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                startLockTask()
                isLockTaskActive = true

                // Enable lock screen flags so the activity shows over lock screen
                // during strict focus. This is a legitimate use case for focus/productivity apps.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    setShowWhenLocked(true)
                    setTurnScreenOn(true)
                } else {
                    @Suppress("DEPRECATION")
                    window.addFlags(
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                    )
                }

                true
            } else {
                false
            }
        } catch (e: SecurityException) {
            // SecurityException: app is not device owner or profile owner
            // On standard personal phones, startLockTask() may throw
            // This is expected — fall back to Flutter-level restrictions
            // The Flutter side (PopScope, navigation blocking) provides the actual protection.
            false
        } catch (e: Exception) {
            false
        }
    }

    private fun exitLockTask(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                stopLockTask()
                isLockTaskActive = false

                // Clear lock screen flags.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    setShowWhenLocked(false)
                    setTurnScreenOn(false)
                } else {
                    @Suppress("DEPRECATION")
                    window.clearFlags(
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                    )
                }

                true
            } else {
                false
            }
        } catch (e: Exception) {
            isLockTaskActive = false
            false
        }
    }

    private fun isLockTaskActive(): Boolean {
        return try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val systemReported = activityManager.isInLockTaskMode
                // Also check our local flag for cases where system reports false
                // but we know we started lock task (can happen on some OEM ROMs).
                systemReported || isLockTaskActive
            } else {
                false
            }
        } catch (e: Exception) {
            isLockTaskActive
        }
    }

    private fun setLockScreenFlags(enabled: Boolean) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(enabled)
                setTurnScreenOn(enabled)
            } else {
                @Suppress("DEPRECATION")
                if (enabled) {
                    window.addFlags(
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                    )
                } else {
                    window.clearFlags(
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                    )
                }
            }
        } catch (e: Exception) {
            // Ignore — flags are best-effort
        }
    }
}
