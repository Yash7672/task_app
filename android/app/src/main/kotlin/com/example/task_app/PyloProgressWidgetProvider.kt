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
class PyloProgressWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.pylo_progress_widget).apply {
                // ── Root tap: open PYLO dashboard ──
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = "WIDGET_OPEN_DASHBOARD"
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    widgetId,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                val total = widgetData.getInt("progress_total", 0)
                val done = widgetData.getInt("progress_done", 0)
                val percent = widgetData.getInt("progress_percent", 0)
                val remaining = widgetData.getInt("progress_remaining", 0)

                if (total > 0) {
                    setViewVisibility(R.id.widget_empty, View.GONE)
                    setViewVisibility(R.id.widget_counts, View.VISIBLE)
                    setViewVisibility(R.id.widget_percent, View.VISIBLE)
                    setViewVisibility(R.id.widget_remaining, View.VISIBLE)

                    setTextViewText(R.id.widget_counts, "$done / $total")
                    setTextViewText(R.id.widget_percent, "$percent%")

                    val remainingText = if (remaining == 1) {
                        "1 task remaining"
                    } else {
                        "$remaining tasks remaining"
                    }
                    setTextViewText(R.id.widget_remaining, remainingText)
                } else {
                    setViewVisibility(R.id.widget_empty, View.VISIBLE)
                    setViewVisibility(R.id.widget_counts, View.GONE)
                    setViewVisibility(R.id.widget_percent, View.GONE)
                    setViewVisibility(R.id.widget_remaining, View.GONE)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
