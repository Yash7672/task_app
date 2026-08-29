package com.example.task_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
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
                // ── Root tap: open PYLO ──
                val pendingIntent =
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                val total = widgetData.getInt("tasks_total", 0)
                val done = widgetData.getInt("tasks_done", 0)
                val pending = widgetData.getInt("tasks_pending", 0)
                val bestStreak = widgetData.getInt("best_streak", 0)
                val more = widgetData.getInt("tasks_more", 0)

                // ── Header ──
                setTextViewText(
                    R.id.widget_header,
                    "PYLO \u2022 Today"
                )

                // ── Progress ──
                if (total > 0) {
                    setViewVisibility(R.id.widget_progress, View.VISIBLE)
                    setTextViewText(
                        R.id.widget_progress,
                        "\u2713 $done / $total done \u2022 $pending remaining"
                    )
                } else {
                    setViewVisibility(R.id.widget_progress, View.GONE)
                }

                // ── Tasks ──
                val taskViews = intArrayOf(
                    R.id.widget_task_0,
                    R.id.widget_task_1,
                    R.id.widget_task_2,
                    R.id.widget_task_3,
                    R.id.widget_task_4
                )

                var visibleCount = 0
                for ((index, taskViewId) in taskViews.withIndex()) {
                    val title = widgetData.getString("tasks_title_$index", null)
                    val taskId = widgetData.getString("tasks_id_$index", null)
                    val done = widgetData.getBoolean("tasks_done_$index", false)
                    if (title.isNullOrEmpty()) {
                        setViewVisibility(taskViewId, View.GONE)
                    } else {
                        setViewVisibility(taskViewId, View.VISIBLE)
                        val icon = if (done) "\u2713" else "\u25EF"
                        setTextViewText(taskViewId, "$icon $title")
                        visibleCount++

                        // ── Per-task tap: open PYLO with task ID ──
                        if (!taskId.isNullOrEmpty()) {
                            val taskIntent = Intent(context, MainActivity::class.java).apply {
                                action = "WIDGET_OPEN_TASK"
                                putExtra("widget_task_id", taskId)
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                            }
                            val taskPendingIntent = PendingIntent.getActivity(
                                context,
                                widgetId * 100 + index,
                                taskIntent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )
                            setOnClickPendingIntent(taskViewId, taskPendingIntent)
                        }
                    }
                }

                // ── "and X more" indicator ──
                if (more > 0) {
                    setViewVisibility(R.id.widget_more, View.VISIBLE)
                    setTextViewText(R.id.widget_more, "and $more more\u2026")
                } else {
                    setViewVisibility(R.id.widget_more, View.GONE)
                }

                // ── Empty state ──
                if (total == 0) {
                    setViewVisibility(R.id.widget_empty, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.widget_empty, View.GONE)
                }

                // ── Streak ──
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
