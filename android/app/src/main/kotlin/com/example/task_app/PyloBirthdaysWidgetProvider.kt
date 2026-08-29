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
class PyloBirthdaysWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.pylo_birthdays_widget).apply {
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = "WIDGET_OPEN_BIRTHDAYS"
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context, widgetId, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                val count = widgetData.getInt("birthdays_count", 0)

                setTextViewText(R.id.widget_header, "\uD83C\uDF82 BIRTHDAYS")

                val nameViews = intArrayOf(
                    R.id.widget_birthday_0, R.id.widget_birthday_1, R.id.widget_birthday_2
                )

                for ((index, nameViewId) in nameViews.withIndex()) {
                    val name = widgetData.getString("birthday_name_$index", null)
                    val whenText = widgetData.getString("birthday_when_$index", null)

                    if (name.isNullOrEmpty()) {
                        setViewVisibility(nameViewId, View.GONE)
                    } else {
                        setViewVisibility(nameViewId, View.VISIBLE)
                        val whenLabel = whenText ?: ""
                        setTextViewText(nameViewId, "$name       $whenLabel")
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
