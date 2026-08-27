package com.example.task_app

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "pylo/focus"

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
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    private fun enterLockTask(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                startLockTask()
                true
            } else {
                false
            }
        } catch (e: SecurityException) {
            // SecurityException: app is not device owner or profile owner
            // On standard personal phones, startLockTask() may throw
            // This is expected — fall back to Flutter-level restrictions
            false
        } catch (e: Exception) {
            false
        }
    }

    private fun exitLockTask(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                stopLockTask()
                true
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun isLockTaskActive(): Boolean {
        return try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                activityManager.isInLockTaskMode
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }
}
