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
class PyloHabitsWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.pylo_habits_widget).apply {
                // Root tap: open PYLO Streaks/Habits page
                val pendingIntent =
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                val count = widgetData.getInt("habits_count", 0)
                val bestStreak = widgetData.getInt("habits_best_streak", 0)

                // Header
                val headerText = if (bestStreak > 0) {
                    "\uD83D\uDD25 Habit Streaks \u2022 $bestStreak day best"
                } else {
                    "\uD83D\uDD25 Habit Streaks"
                }
                setTextViewText(R.id.widget_header, headerText)

                // Habits - name + streak, no checkboxes
                val habitViews = intArrayOf(
                    R.id.widget_habit_0,
                    R.id.widget_habit_1,
                    R.id.widget_habit_2,
                    R.id.widget_habit_3,
                    R.id.widget_habit_4
                )

                for ((index, habitViewId) in habitViews.withIndex()) {
                    val name = widgetData.getString("habits_name_$index", null)
                    val streak = widgetData.getInt("habits_streak_$index", 0)

                    if (name.isNullOrEmpty()) {
                        setViewVisibility(habitViewId, View.GONE)
                    } else {
                        setViewVisibility(habitViewId, View.VISIBLE)
                        val streakText = if (streak > 0) "      ${streak} days" else "      0 days"
                        setTextViewText(habitViewId, "$name$streakText")
                    }
                }

                // Empty state
                if (count == 0) {
                    setViewVisibility(R.id.widget_empty, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.widget_empty, View.GONE)
                }

                // Today summary
                val completedToday = widgetData.getInt("habits_completed_today", 0)
                if (count > 0) {
                    setViewVisibility(R.id.widget_today_summary, View.VISIBLE)
                    setTextViewText(R.id.widget_today_summary, "Today: $completedToday / $count completed")
                } else {
                    setViewVisibility(R.id.widget_today_summary, View.GONE)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
