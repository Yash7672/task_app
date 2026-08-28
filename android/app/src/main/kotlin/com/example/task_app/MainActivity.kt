package com.example.task_app

import android.Manifest
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "pylo/focus"
    private var isLockTaskActive = false
    private var pendingWidgetAction: String? = null
    private var pendingWidgetTaskId: String? = null
    private var pendingWidgetHabitId: String? = null

    private var phoneStateListener: Any? = null
    private var telephonyManager: TelephonyManager? = null
    private var exitedLockTaskForCall = false
    private var flutterEngineRef: FlutterEngine? = null

    private val PHONE_STATE_PERMISSION_REQUEST = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngineRef = flutterEngine

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
                    "requestPhoneStatePermission" -> {
                        result.success(requestPhoneStatePermission())
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

    override fun onDestroy() {
        stopPhoneStateListener()
        super.onDestroy()
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

                startPhoneStateListener()

                true
            } else {
                false
            }
        } catch (e: SecurityException) {
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

                stopPhoneStateListener()

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
        }
    }

    // ── Phone state listener ──────────────────────────────────────────

    private fun requestPhoneStatePermission(): Boolean {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE)
            != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.READ_PHONE_STATE),
                PHONE_STATE_PERMISSION_REQUEST
            )
            return false
        }
        return true
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PHONE_STATE_PERMISSION_REQUEST) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startPhoneStateListener()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun startPhoneStateListener() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE)
            != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        stopPhoneStateListener()

        telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager

        val listener = object : PhoneStateListener() {
            @Deprecated("Deprecated in Java")
            override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                handlePhoneCallState(state)
            }
        }
        telephonyManager?.listen(listener, PhoneStateListener.LISTEN_CALL_STATE)
        phoneStateListener = listener
    }

    private fun stopPhoneStateListener() {
        @Suppress("DEPRECATION")
        if (phoneStateListener != null && telephonyManager != null) {
            telephonyManager?.listen(phoneStateListener as PhoneStateListener, PhoneStateListener.LISTEN_NONE)
            phoneStateListener = null
        }
    }

    private fun handlePhoneCallState(state: Int) {
        when (state) {
            TelephonyManager.CALL_STATE_RINGING, TelephonyManager.CALL_STATE_OFFHOOK -> {
                if (isLockTaskActive && !exitedLockTaskForCall) {
                    exitedLockTaskForCall = true
                    temporarilyReleaseLockTask()
                }
            }
            TelephonyManager.CALL_STATE_IDLE -> {
                if (exitedLockTaskForCall) {
                    exitedLockTaskForCall = false
                    reacquireLockTaskIfNeeded()
                }
            }
        }
    }

    private fun temporarilyReleaseLockTask() {
        try {
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

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    stopLockTask()
                }
            } catch (_: Exception) {
            }

            notifyFlutterCallState("call_active")
        } catch (_: Exception) {
        }
    }

    private fun reacquireLockTaskIfNeeded() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val hasActiveFocus = prefs.contains("flutter.focus_start_ms")

            if (!hasActiveFocus) {
                notifyFlutterCallState("call_ended")
                return
            }

            val focusMode = prefs.getString("flutter.focus_mode", "normal")
            if (focusMode != "strict") {
                notifyFlutterCallState("call_ended")
                return
            }

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    startLockTask()
                    isLockTaskActive = true
                }
            } catch (_: SecurityException) {
                isLockTaskActive = false
            }

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

            notifyFlutterCallState("call_ended")
        } catch (_: Exception) {
            notifyFlutterCallState("call_ended")
        }
    }

    private fun notifyFlutterCallState(state: String) {
        try {
            flutterEngineRef?.let { engine ->
                MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod("onCallStateChanged", state)
            }
        } catch (_: Exception) {
        }
    }
}
