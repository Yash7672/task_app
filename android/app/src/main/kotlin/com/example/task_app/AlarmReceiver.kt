package com.example.task_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Receives every exact task-alarm broadcast from Android's AlarmManager.
 *
 * Its ONLY job is to bring the full-screen [AlarmActivity] forward. The
 * activity starts audio + vibration. The scheduled alarm itself — not any
 * notification tap — is the trigger for the ring.
 */
class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != AlarmScheduler.ACTION_ALARM) return

        val requestCode = intent.getIntExtra(AlarmScheduler.EXTRA_REQUEST_CODE, 0)
        val taskId = intent.getStringExtra(AlarmScheduler.EXTRA_TASK_ID).orEmpty()
        if (taskId.isEmpty()) return

        val title = intent.getStringExtra(AlarmScheduler.EXTRA_TASK_TITLE)
            ?: context.getString(R.string.app_name)
        val alarmTimeMs = intent.getLongExtra(
            AlarmScheduler.EXTRA_ALARM_TIME_MS,
            System.currentTimeMillis()
        )

        try {
            val show = Intent(context, AlarmActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
                putExtra(AlarmScheduler.EXTRA_REQUEST_CODE, requestCode)
                putExtra(AlarmScheduler.EXTRA_TASK_ID, taskId)
                putExtra(AlarmScheduler.EXTRA_TASK_TITLE, title)
                putExtra(AlarmScheduler.EXTRA_ALARM_TIME_MS, alarmTimeMs)
            }
            context.startActivity(show)
        } catch (_: Exception) {
        }
    }
}