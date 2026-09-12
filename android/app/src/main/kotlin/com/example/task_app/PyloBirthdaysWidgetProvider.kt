package com.example.task_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import androidx.annotation.Keep
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Calendar-style Birthdays widget.
 *
 * Renders a dark month grid: ‹ › arrows navigate months (broadcast back to
 * this provider, which shifts the persisted view month and re-renders), the
 * current device day gets an amber circle, and every matching birthday day
 * shows a 🎂. Tapping a 🎂 day or the month header opens the Birthdays screen.
 */
@Keep
class PyloBirthdaysWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        render(context, appWidgetManager, appWidgetIds)
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        when (intent.action) {
            ACTION_PREV_MONTH, ACTION_NEXT_MONTH -> {
                val delta = if (intent.action == ACTION_PREV_MONTH) -1 else 1
                val data = prefs(context)
                val newMonth = resolveViewMonth(data) + delta
                data.edit().putInt(KEY_VIEW_MONTH, newMonth).apply()
                val manager = AppWidgetManager.getInstance(context)
                val ids = manager.getAppWidgetIds(
                    ComponentName(context, PyloBirthdaysWidgetProvider::class.java)
                )
                if (ids.isNotEmpty()) {
                    render(context, manager, ids)
                }
            }
            else -> super.onReceive(context, intent)
        }
    }

    private fun render(
        context: Context,
        manager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val data = prefs(context)

        // Resolve the month to show: a past month always rolls forward to the
        // device month so the widget never stays stuck on a stale month, while
        // a future month (deliberate user navigation) is preserved.
        val deviceCal = Calendar.getInstance()
        val currentYyyymm = deviceCal.get(Calendar.YEAR) * 100 +
                (deviceCal.get(Calendar.MONTH) + 1)
        val stored = data.getInt(KEY_VIEW_MONTH, 0)
        val view = if (stored in 1..currentYyyymm) stored else currentYyyymm
        if (view != stored) {
            data.edit().putInt(KEY_VIEW_MONTH, view).apply()
        }

        val viewCal = Calendar.getInstance().apply {
            clear()
            set(view / 100, view % 100 - 1, 1)
        }
        val isCurrentMonth = view == currentYyyymm
        val todayDay = deviceCal.get(Calendar.DAY_OF_MONTH)
        val daysInMonth = viewCal.getActualMaximum(Calendar.DAY_OF_MONTH)
        val leadingBlanks = viewCal.get(Calendar.DAY_OF_WEEK) - Calendar.SUNDAY

        val count = data.getInt("birthdays_count", 0)
        val markers = parseMarkers(
            data.getString("birthday_markers", null),
            view % 100 - 1,
            daysInMonth
        )

        val monthTitle = titleCase(
            SimpleDateFormat("MMMM yyyy", Locale.getDefault()).format(viewCal.time)
        )
        val todayColor = ContextCompat.getColor(context, R.color.widget_on_accent_color)
        val dayColor = ContextCompat.getColor(context, R.color.widget_task_color)

        appWidgetIds.forEach { widgetId ->
            val views = buildViews(
                context = context,
                widgetId = widgetId,
                monthTitle = monthTitle,
                count = count,
                leadingBlanks = leadingBlanks,
                daysInMonth = daysInMonth,
                markers = markers,
                isCurrentMonth = isCurrentMonth,
                todayDay = todayDay,
                todayColor = todayColor,
                dayColor = dayColor
            )
            manager.updateAppWidget(widgetId, views)
        }
    }

    private fun buildViews(
        context: Context,
        widgetId: Int,
        monthTitle: String,
        count: Int,
        leadingBlanks: Int,
        daysInMonth: Int,
        markers: Set<Int>,
        isCurrentMonth: Boolean,
        todayDay: Int,
        todayColor: Int,
        dayColor: Int
    ): RemoteViews {
        return RemoteViews(context.packageName, R.layout.pylo_birthdays_widget).apply {
            // Whole widget (header included) opens the Birthdays screen.
            setOnClickPendingIntent(R.id.widget_root, openBirthdays(context, widgetId, 0))

            // Month navigation.
            setOnClickPendingIntent(
                R.id.widget_prev, action(context, ACTION_PREV_MONTH, widgetId, 1)
            )
            setOnClickPendingIntent(
                R.id.widget_next, action(context, ACTION_NEXT_MONTH, widgetId, 2)
            )

            setTextViewText(R.id.widget_month, monthTitle)
            setViewVisibility(R.id.widget_empty, if (count == 0) View.VISIBLE else View.GONE)

            for (i in 0 until 42) {
                val dayNumber = i - leadingBlanks + 1
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                    setViewVisibility(dayViewId(i), View.INVISIBLE)
                    continue
                }
                val viewId = dayViewId(i)
                setViewVisibility(viewId, View.VISIBLE)

                val isBirthday = markers.contains(dayNumber)
                val isToday = isCurrentMonth && dayNumber == todayDay

                // 🎂 rides under the day number so both stay legible in a small cell.
                setTextViewText(
                    viewId,
                    if (isBirthday) "$dayNumber\n\uD83C\uDF82" else dayNumber.toString()
                )
                setTextColor(viewId, if (isToday) todayColor else dayColor)
                setInt(
                    viewId,
                    "setBackgroundResource",
                    when {
                        isToday -> R.drawable.pylo_widget_day_active
                        isBirthday -> R.drawable.pylo_widget_day_birthday
                        else -> 0
                    }
                )

                if (isBirthday) {
                    setOnClickPendingIntent(viewId, openBirthdays(context, widgetId, 0))
                }
            }
        }
    }

    /** Parses "MM-DD,MM-DD" into the day numbers falling within the displayed
     *  month. Days beyond the month's length (e.g. Feb 29 in a non-leap year)
     *  clamp to the last valid day, matching the app's Feb-28 fallback. */
    private fun parseMarkers(raw: String?, displayMonthIndex: Int, daysInMonth: Int): Set<Int> {
        if (raw.isNullOrBlank()) return emptySet()
        return raw.split(',').mapNotNull { token ->
            val parts = token.split('-')
            if (parts.size != 2) return@mapNotNull null
            val mm = parts[0].toIntOrNull() ?: return@mapNotNull null
            val dd = parts[1].toIntOrNull() ?: return@mapNotNull null
            if (mm - 1 != displayMonthIndex) return@mapNotNull null
            dd.coerceIn(1, daysInMonth)
        }.toSet()
    }

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)

    /** Persisted view month (yyyyMM), or the device month when unset. */
    private fun resolveViewMonth(data: SharedPreferences): Int {
        val stored = data.getInt(KEY_VIEW_MONTH, 0)
        if (stored > 0) return stored
        val cal = Calendar.getInstance()
        return cal.get(Calendar.YEAR) * 100 + (cal.get(Calendar.MONTH) + 1)
    }

    private fun titleCase(value: String): String = value.replaceFirstChar { it.uppercase() }

    private fun openBirthdays(
        context: Context,
        widgetId: Int,
        requestCode: Int
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = "WIDGET_OPEN_BIRTHDAYS"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context, requestCode * 31 + widgetId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun action(
        context: Context,
        action: String,
        widgetId: Int,
        requestCode: Int
    ): PendingIntent {
        val intent = Intent(context, PyloBirthdaysWidgetProvider::class.java).apply {
            this.action = action
        }
        return PendingIntent.getBroadcast(
            context, requestCode * 31 + widgetId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun dayViewId(index: Int): Int = when (index) {
        0 -> R.id.widget_day_0
        1 -> R.id.widget_day_1
        2 -> R.id.widget_day_2
        3 -> R.id.widget_day_3
        4 -> R.id.widget_day_4
        5 -> R.id.widget_day_5
        6 -> R.id.widget_day_6
        7 -> R.id.widget_day_7
        8 -> R.id.widget_day_8
        9 -> R.id.widget_day_9
        10 -> R.id.widget_day_10
        11 -> R.id.widget_day_11
        12 -> R.id.widget_day_12
        13 -> R.id.widget_day_13
        14 -> R.id.widget_day_14
        15 -> R.id.widget_day_15
        16 -> R.id.widget_day_16
        17 -> R.id.widget_day_17
        18 -> R.id.widget_day_18
        19 -> R.id.widget_day_19
        20 -> R.id.widget_day_20
        21 -> R.id.widget_day_21
        22 -> R.id.widget_day_22
        23 -> R.id.widget_day_23
        24 -> R.id.widget_day_24
        25 -> R.id.widget_day_25
        26 -> R.id.widget_day_26
        27 -> R.id.widget_day_27
        28 -> R.id.widget_day_28
        29 -> R.id.widget_day_29
        30 -> R.id.widget_day_30
        31 -> R.id.widget_day_31
        32 -> R.id.widget_day_32
        33 -> R.id.widget_day_33
        34 -> R.id.widget_day_34
        35 -> R.id.widget_day_35
        36 -> R.id.widget_day_36
        37 -> R.id.widget_day_37
        38 -> R.id.widget_day_38
        39 -> R.id.widget_day_39
        40 -> R.id.widget_day_40
        41 -> R.id.widget_day_41
        else -> R.id.widget_day_0
    }

    companion object {
        private const val ACTION_PREV_MONTH =
            "com.example.task_app.action.BIRTHDAYS_PREV"
        private const val ACTION_NEXT_MONTH =
            "com.example.task_app.action.BIRTHDAYS_NEXT"
        private const val KEY_VIEW_MONTH = "birthday_view_month"

        /** SharedPreferences file the home_widget plugin writes into. */
        private const val PREF_NAME = "HomeWidgetPreferences"
    }
}