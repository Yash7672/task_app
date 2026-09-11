package com.example.task_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import androidx.annotation.Keep
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
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

                // Tasks — each row has a checkbox ImageView + title TextView.
                // The checkbox sends a broadcast to toggle completion; tapping
                // the row itself opens the app.
                val taskViewIds = intArrayOf(
                    R.id.widget_task_0,
                    R.id.widget_task_1,
                    R.id.widget_task_2,
                    R.id.widget_task_3,
                    R.id.widget_task_4
                )
                val checkboxIds = intArrayOf(
                    R.id.widget_checkbox_0,
                    R.id.widget_checkbox_1,
                    R.id.widget_checkbox_2,
                    R.id.widget_checkbox_3,
                    R.id.widget_checkbox_4
                )
                val rowIds = intArrayOf(
                    R.id.widget_row_0,
                    R.id.widget_row_1,
                    R.id.widget_row_2,
                    R.id.widget_row_3,
                    R.id.widget_row_4
                )

                for (i in taskViewIds.indices) {
                    val title = widgetData.getString("tasks_title_$i", null)
                    val taskId = widgetData.getString("tasks_id_$i", null)
                    val isCompleted = widgetData.getBoolean("tasks_done_$i", false)

                    if (title.isNullOrEmpty()) {
                        setViewVisibility(rowIds[i], View.GONE)
                    } else {
                        setViewVisibility(rowIds[i], View.VISIBLE)
                        setTextViewText(taskViewIds[i], title)

                        // Strikethrough for completed tasks.
                        if (isCompleted) {
                            // Apply strikethrough via RemoteViews (setPaintFlags is not
                            // available, so we use a style change approach).
                            setTextViewText(taskViewIds[i], "\u2714 $title")
                        } else {
                            setTextViewText(taskViewIds[i], title)
                        }

                        // Checkbox icon
                        val checkboxRes = if (isCompleted)
                            R.drawable.widget_checkbox_checked
                        else
                            R.drawable.widget_checkbox_unchecked
                        setImageViewResource(checkboxIds[i], checkboxRes)

                        // Wire the checkbox tap to the background interactivity
                        // receiver so the Dart callback toggles the task.
                        if (!taskId.isNullOrEmpty() && !isCompleted) {
                            val uri = Uri.Builder()
                                .scheme("pylo")
                                .authority("complete_task")
                                .appendQueryParameter("id", taskId)
                                .appendQueryParameter("index", i.toString())
                                .build()
                            val broadcastIntent = HomeWidgetBackgroundIntent.getBroadcast(
                                context, uri
                            )
                            setOnClickPendingIntent(checkboxIds[i], broadcastIntent)
                        } else {
                            // Already completed — tap does nothing (no pending intent).
                            setOnClickPendingIntent(checkboxIds[i], null)
                        }
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
