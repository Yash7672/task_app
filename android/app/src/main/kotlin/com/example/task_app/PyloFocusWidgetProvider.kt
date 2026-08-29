package com.example.task_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import androidx.annotation.Keep
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

@Keep
class PyloFocusWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.pylo_focus_widget).apply {
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = "WIDGET_OPEN_FOCUS"
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context, widgetId, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                val isActive = widgetData.getBoolean("focus_active", false)
                val label = widgetData.getString("focus_label", "") ?: ""
                val remainingMinutes = widgetData.getInt("focus_remaining_minutes", 0)
                val remainingSeconds = widgetData.getInt("focus_remaining_seconds", 0)
                val isStrict = widgetData.getBoolean("focus_strict", false)

                if (isActive) {
                    setViewVisibility(R.id.widget_inactive, View.GONE)
                    setViewVisibility(R.id.widget_active, View.VISIBLE)

                    val modeText = if (isStrict) "LOCKED FOCUS" else "FOCUS ACTIVE"
                    setTextViewText(R.id.widget_mode, "\uD83D\uDD12 $modeText")

                    val mins = remainingMinutes.toString().padStart(2, '0')
                    val secs = remainingSeconds.toString().padStart(2, '0')
                    setTextViewText(R.id.widget_timer, "$mins:$secs")

                    if (label.isNotEmpty()) {
                        setViewVisibility(R.id.widget_label, View.VISIBLE)
                        setTextViewText(R.id.widget_label, label)
                    } else {
                        setViewVisibility(R.id.widget_label, View.GONE)
                    }
                } else {
                    setViewVisibility(R.id.widget_inactive, View.VISIBLE)
                    setViewVisibility(R.id.widget_active, View.GONE)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
