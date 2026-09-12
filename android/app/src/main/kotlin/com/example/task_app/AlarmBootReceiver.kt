package com.example.task_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Re-arms future task alarms after a reboot or app update (AlarmManager drops
 * all pending alarms across a reboot). Reads the pending-alarm mirror written
 * by [AlarmScheduler] and reschedules everything still in the future.
 */
class AlarmBootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        when (action) {
            Intent.ACTION_BOOT_COMPLETED ->
                AlarmScheduler.rescheduleAll(context)
            Intent.ACTION_MY_PACKAGE_REPLACED ->
                AlarmScheduler.rescheduleAll(context)
            "android.intent.action.QUICKBOOT_POWERON" ->
                AlarmScheduler.rescheduleAll(context)
            "com.htc.intent.action.QUICKBOOT_POWERON" ->
                AlarmScheduler.rescheduleAll(context)
        }
    }
}