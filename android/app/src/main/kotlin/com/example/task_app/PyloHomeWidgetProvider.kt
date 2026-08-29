package com.example.task_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import androidx.annotation.Keep
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

@Keep
class PyloHomeWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.pylo_home_widget).apply {
                // Root tap: open PYLO Tasks page
                val pendingIntent =
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                val total = widgetData.getInt("tasks_total", 0)
                val done = widgetData.getInt("tasks_done", 0)
                val pending = widgetData.getInt("tasks_pending", 0)
                val bestStreak = widgetData.getInt("best_streak", 0)
                val more = widgetData.getInt("tasks_more", 0)

                // Header
                setTextViewText(R.id.widget_header, "Today's Tasks")

                // Progress
                if (total > 0) {
                    setViewVisibility(R.id.widget_progress, View.VISIBLE)
                    setTextViewText(
                        R.id.widget_progress,
                        "$done / $total completed"
                    )
                } else {
                    setViewVisibility(R.id.widget_progress, View.GONE)
                }

                // Tasks - bullet list, no checkboxes
                val taskViews = intArrayOf(
                    R.id.widget_task_0,
                    R.id.widget_task_1,
                    R.id.widget_task_2,
                    R.id.widget_task_3,
                    R.id.widget_task_4
                )

                for ((index, taskViewId) in taskViews.withIndex()) {
                    val title = widgetData.getString("tasks_title_$index", null)
                    if (title.isNullOrEmpty()) {
                        setViewVisibility(taskViewId, View.GONE)
                    } else {
                        setViewVisibility(taskViewId, View.VISIBLE)
                        setTextViewText(taskViewId, "\u2022 $title")
                    }
                }

                // "and X more" indicator
                if (more > 0) {
                    setViewVisibility(R.id.widget_more, View.VISIBLE)
                    setTextViewText(R.id.widget_more, "and $more more\u2026")
                } else {
                    setViewVisibility(R.id.widget_more, View.GONE)
                }

                // Empty state
                if (total == 0) {
                    setViewVisibility(R.id.widget_empty, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.widget_empty, View.GONE)
                }

                // Streak
                if (bestStreak > 0) {
                    setViewVisibility(R.id.widget_streak, View.VISIBLE)
                    setTextViewText(R.id.widget_streak, "\uD83D\uDD25 $bestStreak day streak")
                } else {
                    setViewVisibility(R.id.widget_streak, View.GONE)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
