package com.kidyoh.glass_calendar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import java.util.Calendar
import java.util.Locale

/**
 * Shared renderer for the two home-screen widgets.
 *
 * Dates and the week strip are computed here from the system clock so the
 * widget is correct across midnight; Flutter (home_widget) only supplies the
 * per-day event counts and the next event, via SharedPreferences.
 */
private object WidgetRenderer {
    private val ids = listOf(0, 1, 2, 3, 4, 5, 6)
    private val wdIds = intArrayOf(R.id.wd0, R.id.wd1, R.id.wd2, R.id.wd3, R.id.wd4, R.id.wd5, R.id.wd6)
    private val numIds = intArrayOf(R.id.num0, R.id.num1, R.id.num2, R.id.num3, R.id.num4, R.id.num5, R.id.num6)
    private val dotIds = intArrayOf(R.id.dot0, R.id.dot1, R.id.dot2, R.id.dot3, R.id.dot4, R.id.dot5, R.id.dot6)
    private val letters = arrayOf("S", "M", "T", "W", "T", "F", "S") // Calendar.SUNDAY = 1
    private val shortNames = arrayOf("Su", "Mo", "Tu", "We", "Th", "Fr", "Sa")

    private fun key(c: Calendar) = String.format(
        Locale.US, "%04d%02d%02d", c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH)
    )

    private fun counts(raw: String?): Map<String, Int> =
        raw.orEmpty().split(",").mapNotNull {
            val p = it.split(":")
            if (p.size == 2) p[0] to (p[1].toIntOrNull() ?: 0) else null
        }.toMap()

    fun render(context: Context, glass: Boolean): RemoteViews {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val views = RemoteViews(
            context.packageName,
            if (glass) R.layout.glass_widget else R.layout.island_widget
        )
        val today = Calendar.getInstance()
        val mondayFirst = prefs.getString("week_monday", "1") != "0"
        val byDay = counts(prefs.getString("counts", ""))

        // First day of the displayed week.
        val start = today.clone() as Calendar
        val dow = start.get(Calendar.DAY_OF_WEEK) // 1 = Sunday
        val back = if (mondayFirst) (dow + 5) % 7 else dow - 1
        start.add(Calendar.DAY_OF_MONTH, -back)

        val monthName = today.getDisplayName(Calendar.MONTH, Calendar.LONG, Locale.getDefault()) ?: ""
        val todayCount = byDay[key(today)] ?: 0

        if (glass) {
            views.setTextViewText(R.id.month, monthName)
            views.setTextViewText(R.id.day, today.get(Calendar.DAY_OF_MONTH).toString())
            val title = prefs.getString("next_title", "") ?: ""
            val whenText = prefs.getString("next_when", "") ?: ""
            views.setTextViewText(
                R.id.next,
                if (title.isEmpty()) "No upcoming events" else "$whenText · $title"
            )
        } else {
            views.setTextViewText(R.id.month, monthName)
            views.setTextViewText(
                R.id.day,
                if (todayCount == 1) "1 event" else "$todayCount events"
            )
        }

        for (i in ids) {
            val d = start.clone() as Calendar
            d.add(Calendar.DAY_OF_MONTH, i)
            val idx = d.get(Calendar.DAY_OF_WEEK) - 1
            val isToday = key(d) == key(today)
            views.setTextViewText(wdIds[i], if (glass) letters[idx] else shortNames[idx])
            views.setTextViewText(numIds[i], d.get(Calendar.DAY_OF_MONTH).toString())
            views.setTextColor(numIds[i], if (isToday) Color.BLACK else Color.WHITE)
            views.setInt(
                numIds[i], "setBackgroundResource",
                if (isToday) (if (glass) R.drawable.sel_glass else R.drawable.sel_island) else 0
            )
            val has = (byDay[key(d)] ?: 0) > 0
            views.setTextColor(dotIds[i], if (has) Color.parseColor("#CCFFFFFF") else Color.TRANSPARENT)
        }

        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launch != null) {
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
            val pi = PendingIntent.getActivity(
                context, if (glass) 1 else 2, launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.root, pi)
        }
        return views
    }
}

class GlassWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) manager.updateAppWidget(id, WidgetRenderer.render(context, true))
    }
}

class IslandWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) manager.updateAppWidget(id, WidgetRenderer.render(context, false))
    }
}
