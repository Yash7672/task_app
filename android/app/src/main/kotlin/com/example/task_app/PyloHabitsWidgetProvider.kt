package com.example.task_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class PyloHabitsWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.pylo_habits_widget).apply {
                // ── Root tap: open PYLO habits ──
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = "WIDGET_OPEN_HABITS"
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    widgetId,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                val count = widgetData.getInt("habits_count", 0)
                val bestStreak = widgetData.getInt("habits_best_streak", 0)

                // ── Header ──
                val headerText = if (bestStreak > 0) {
                    "\uD83D\uDD25 Habits \u2022 $bestStreak day best"
                } else {
                    "\uD83D\uDD25 Habits"
                }
                setTextViewText(R.id.widget_header, headerText)

                // ── Habits ──
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
                    val done = widgetData.getBoolean("habits_done_$index", false)
                    val habitId = widgetData.getString("habits_id_$index", null)

                    if (name.isNullOrEmpty()) {
                        setViewVisibility(habitViewId, View.GONE)
                    } else {
                        setViewVisibility(habitViewId, View.VISIBLE)
                        val icon = if (done) "\u2713" else "\u25EF"
                        val streakText = if (streak > 0) " \u2022 ${streak}d" else ""
                        setTextViewText(habitViewId, "$icon $name$streakText")

                        // ── Per-habit tap: open PYLO habits ──
                        if (!habitId.isNullOrEmpty()) {
                            val habitIntent = Intent(context, MainActivity::class.java).apply {
                                action = "WIDGET_OPEN_HABITS"
                                putExtra("widget_habit_id", habitId)
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                            }
                            val habitPendingIntent = PendingIntent.getActivity(
                                context,
                                widgetId * 100 + index,
                                habitIntent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )
                            setOnClickPendingIntent(habitViewId, habitPendingIntent)
                        }
                    }
                }

                // ── Empty state ──
                if (count == 0) {
                    setViewVisibility(R.id.widget_empty, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.widget_empty, View.GONE)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
