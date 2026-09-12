package com.example.task_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

/**
 * Schedules and cancels PYLO task alarms through Android's AlarmManager.
 *
 * Every alarm is a distinct broadcast PendingIntent to [AlarmReceiver]. The
 * receiver launches the full-screen [AlarmActivity], which owns audio playback
 * and vibration, so a task alarm rings and shows its UI completely free of the
 * notification tap path — and runs whether the Flutter app is open,
 * backgrounded, or dead.
 *
 * Global alarm sound / vibration / snooze preferences are read from the
 * shared_preferences plugin data store at RING time (never embedded per task),
 * so the user configures music exactly once in Settings and every task alarm
 * uses the current global choice.
 *
 * A lightweight mirror of future alarms is kept in SharedPreferences so a
 * BOOT_COMPLETED / package-replaced receiver can re-arm them (AlarmManager
 * clears all pending alarms on reboot).
 */
object AlarmScheduler {
    const val EXTRA_REQUEST_CODE = "pylo_alarm_request_code"
    const val EXTRA_TASK_ID = "pylo_alarm_task_id"
    const val EXTRA_TASK_TITLE = "pylo_alarm_task_title"
    const val EXTRA_ALARM_TIME_MS = "pylo_alarm_time_ms"

    const val ACTION_ALARM = "com.example.task_app.ACTION_TASK_ALARM"

    /** SharedPreferences file + key prefix used by the shared_preferences plugin. */
    const val FLUTTER_PREFS = "FlutterSharedPreferences"
    const val PREF_SOUND_ID = "flutter.alarm_sound_id"
    const val PREF_CUSTOM_URI = "flutter.custom_alarm_uri"
    const val PREF_VIBRATE = "flutter.alarm_vibrate"
    const val PREF_SNOOZE_MIN = "flutter.alarm_snooze_minutes"

    private const val PREFS = "pylo_alarm_prefs"
    private const val KEY_PENDING = "pylo_pending_alarms"

    /**
     * Schedules an exact (or best-effort inexact) alarm at [timeMs].
     * Returns true when a real exact alarm was armed.
     */
    fun schedule(context: Context, requestCode: Int, timeMs: Long, taskId: String, title: String): Boolean {
        try {
            val pi = PendingIntent.getBroadcast(
                context,
                requestCode,
                buildTriggerIntent(context, requestCode, timeMs, taskId, title),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val exact = canScheduleExact(context)
            if (exact) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pi)
            } else {
                // SCHEDULE_EXACT_ALARM denied -> still arm, just inexact (may
                // fire a little late). Better than never ringing.
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pi)
            }
            savePending(context, requestCode, timeMs, taskId, title)
            return exact
        } catch (e: Exception) {
            return false
        }
    }

    fun cancel(context: Context, requestCode: Int) {
        try {
            val pi = PendingIntent.getBroadcast(
                context,
                requestCode,
                buildTriggerIntent(context, requestCode, 0L, "", ""),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.cancel(pi)
            pi.cancel()
        } catch (_: Exception) {
        }
        removePending(context, requestCode)
    }

    fun canScheduleExact(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return try {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.canScheduleExactAlarms()
        } catch (_: Exception) {
            true
        }
    }

    fun openExactAlarmSettings(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        try {
            context.startActivity(
                Intent(
                    android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                    Uri.parse("package:${context.packageName}")
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        } catch (_: Exception) {
        }
    }

    private fun buildTriggerIntent(context: Context, requestCode: Int, timeMs: Long, taskId: String, title: String): Intent {
        return Intent(context, AlarmReceiver::class.java).apply {
            action = ACTION_ALARM
            data = Uri.parse("pylo://task_alarm/$requestCode")
            putExtra(EXTRA_REQUEST_CODE, requestCode)
            putExtra(EXTRA_TASK_ID, taskId)
            putExtra(EXTRA_TASK_TITLE, title)
            putExtra(EXTRA_ALARM_TIME_MS, timeMs)
        }
    }

    // ── Pending-alarm mirror (boot re-arm) ──────────────────────────────

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    @Synchronized
    private fun savePending(context: Context, requestCode: Int, timeMs: Long, taskId: String, title: String) {
        val arr = parse(prefs(context).getString(KEY_PENDING, null))
        val cleaned = JSONArray()
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            if (o.optInt("rc") != requestCode && o.optLong("t") > System.currentTimeMillis()) {
                cleaned.put(o)
            }
        }
        cleaned.put(
            JSONObject()
                .put("rc", requestCode)
                .put("t", timeMs)
                .put("id", taskId)
                .put("title", title)
        )
        prefs(context).edit().putString(KEY_PENDING, cleaned.toString()).apply()
    }

    @Synchronized
    private fun removePending(context: Context, requestCode: Int) {
        val arr = parse(prefs(context).getString(KEY_PENDING, null))
        val cleaned = JSONArray()
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            if (o.optInt("rc") != requestCode) cleaned.put(o)
        }
        prefs(context).edit().putString(KEY_PENDING, cleaned.toString()).apply()
    }

    /** Re-arms alarms that are still in the future. Called after boot / update. */
    @Synchronized
    fun rescheduleAll(context: Context) {
        val arr = parse(prefs(context).getString(KEY_PENDING, null))
        val now = System.currentTimeMillis()
        val kept = JSONArray()
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            val timeMs = o.optLong("t")
            if (timeMs <= now) continue
            val requestCode = o.optInt("rc")
            val taskId = o.optString("id", "")
            val title = o.optString("title", "Task")
            if (taskId.isEmpty()) continue
            try {
                val pi = PendingIntent.getBroadcast(
                    context,
                    requestCode,
                    buildTriggerIntent(context, requestCode, timeMs, taskId, title),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                if (canScheduleExact(context)) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pi)
                } else {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pi)
                }
            } catch (_: Exception) {
                continue
            }
            kept.put(o)
        }
        prefs(context).edit().putString(KEY_PENDING, kept.toString()).apply()
    }

    private fun parse(listJson: String?): JSONArray {
        if (listJson.isNullOrBlank()) return JSONArray()
        return try {
            JSONArray(listJson)
        } catch (_: Exception) {
            JSONArray()
        }
    }
}