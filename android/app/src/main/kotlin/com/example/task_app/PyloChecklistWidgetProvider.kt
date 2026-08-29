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
class PyloChecklistWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.pylo_checklist_widget).apply {
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = "WIDGET_OPEN_CHECKLIST"
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context, widgetId, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                val title = widgetData.getString("checklist_title", "") ?: ""
                val count = widgetData.getInt("checklist_count", 0)

                val headerText = if (title.isNotEmpty()) {
                    "\uD83D\uDED2 ${title.uppercase()}"
                } else {
                    "\uD83D\uDED2 CHECKLIST"
                }
                setTextViewText(R.id.widget_header, headerText)

                val itemViews = intArrayOf(
                    R.id.widget_item_0, R.id.widget_item_1, R.id.widget_item_2,
                    R.id.widget_item_3, R.id.widget_item_4
                )

                for ((index, itemViewId) in itemViews.withIndex()) {
                    val text = widgetData.getString("checklist_text_$index", null)
                    val done = widgetData.getBoolean("checklist_done_$index", false)

                    if (text.isNullOrEmpty()) {
                        setViewVisibility(itemViewId, View.GONE)
                    } else {
                        setViewVisibility(itemViewId, View.VISIBLE)
                        val icon = if (done) "\u2713" else "\u25EF"
                        setTextViewText(itemViewId, "$icon $text")
                    }
                }

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
