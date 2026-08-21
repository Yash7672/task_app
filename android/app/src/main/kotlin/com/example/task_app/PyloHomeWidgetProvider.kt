package com.example.task_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class PyloHomeWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.pylo_home_widget).apply {
                val pendingIntent =
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                val taskCount = widgetData.getInt("task_count", 0)
                val doneCount = widgetData.getInt("done_count", 0)
                val bestStreak = widgetData.getInt("best_streak", 0)

                setTextViewText(
                    R.id.widget_header,
                    "PYLO \u2022 Today ($doneCount done)"
                )

                val taskIds = intArrayOf(
                    R.id.widget_task_0,
                    R.id.widget_task_1,
                    R.id.widget_task_2,
                    R.id.widget_task_3,
                    R.id.widget_task_4
                )

                for ((index, taskId) in taskIds.withIndex()) {
                    val title = widgetData.getString("task_$index", null)
                    if (title.isNullOrEmpty()) {
                        setViewVisibility(taskId, View.GONE)
                    } else {
                        setViewVisibility(taskId, View.VISIBLE)
                        setTextViewText(taskId, "\u25EF $title")
                    }
                }

                if (taskCount == 0) {
                    setViewVisibility(R.id.widget_empty, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.widget_empty, View.GONE)
                }

                if (bestStreak > 0) {
                    setViewVisibility(R.id.widget_streak, View.VISIBLE)
                    setTextViewText(R.id.widget_streak, "\uD83D\uDD25 $bestStreak DAY STREAK")
                } else {
                    setViewVisibility(R.id.widget_streak, View.GONE)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
