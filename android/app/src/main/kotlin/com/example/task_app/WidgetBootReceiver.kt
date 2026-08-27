package com.example.task_app

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

class WidgetBootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            // Trigger widget refresh after boot/package update.
            // The widget will display whatever data is in SharedPreferences.
            // When the user opens PYLO, fresh data will be pushed.
            updateAllWidgets(context)
        }
    }

    private fun updateAllWidgets(context: Context) {
        val managers = arrayOf(
            PyloHomeWidgetProvider::class.java,
            PyloHabitsWidgetProvider::class.java,
            PyloProgressWidgetProvider::class.java,
            PyloQuickAddWidgetProvider::class.java,
        )

        for (managerClass in managers) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, managerClass)
            val widgetIds = manager.getAppWidgetIds(component)

            if (widgetIds.isNotEmpty()) {
                val intent = Intent(context, managerClass).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
                }
                context.sendBroadcast(intent)
            }
        }
    }
}
