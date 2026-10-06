package com.kidyoh.glass_calendar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import java.util.Calendar
import org.json.JSONObject
import java.util.Locale

/**
 * Shared renderer for the two home-screen widgets.
 *
 * Dates and the week strip are computed here from the system clock so the
 * widget is correct across midnight; Flutter (home_widget) only supplies the
 * per-day event counts and the next event, via SharedPreferences.
 */
/** Ethiopian calendar conversion (same JDN algorithm as lib/core/ethiopian.dart). */
private object Ethiopian {
    private const val EPOCH = 1723856

    private fun gregToJdn(y: Int, m: Int, d: Int): Int {
        val a = (14 - m) / 12
        val yy = y + 4800 - a
        val mm = m + 12 * a - 3
        return d + (153 * mm + 2) / 5 + 365 * yy + yy / 4 - yy / 100 + yy / 400 - 32045
    }

    /** Returns (year, month 1..13, day). */
    fun fromCalendar(c: Calendar): Triple<Int, Int, Int> {
        val jdn = gregToJdn(c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH))
        val r = Math.floorMod(jdn - EPOCH, 1461)
        val n = r % 365 + 365 * (r / 1460)
        val year = 4 * Math.floorDiv(jdn - EPOCH, 1461) + r / 365 - r / 1460
        return Triple(year, n / 30 + 1, n % 30 + 1)
    }

    val monthsAm = arrayOf(
        "መስከረም", "ጥቅምት", "ኅዳር", "ታኅሣሥ", "ጥር", "የካቲት", "መጋቢት",
        "ሚያዝያ", "ግንቦት", "ሰኔ", "ሐምሌ", "ነሐሴ", "ጳጉሜ"
    )
    val monthsEn = arrayOf(
        "Meskerem", "Tikimt", "Hidar", "Tahsas", "Tir", "Yekatit", "Megabit",
        "Miyazya", "Ginbot", "Sene", "Hamle", "Nehase", "Pagume"
    )
}

object WidgetRenderer {
    private val ids = listOf(0, 1, 2, 3, 4, 5, 6)
    private val wdIds = intArrayOf(R.id.wd0, R.id.wd1, R.id.wd2, R.id.wd3, R.id.wd4, R.id.wd5, R.id.wd6)
    private val numIds = intArrayOf(R.id.num0, R.id.num1, R.id.num2, R.id.num3, R.id.num4, R.id.num5, R.id.num6)
    private val dotIds = intArrayOf(R.id.dot0, R.id.dot1, R.id.dot2, R.id.dot3, R.id.dot4, R.id.dot5, R.id.dot6)
    // Indexed by Calendar.DAY_OF_WEEK - 1 (Sunday first).
    private val letters = arrayOf("S", "M", "T", "W", "T", "F", "S")
    private val shortNames = arrayOf("Su", "Mo", "Tu", "We", "Th", "Fr", "Sa")
    private val lettersAm = arrayOf("እ", "ሰ", "ማ", "ረ", "ሐ", "ዓ", "ቅ")
    private val shortAm = arrayOf("እሑ", "ሰኞ", "ማክ", "ረቡ", "ሐሙ", "ዓር", "ቅዳ")
    private val gregAm = arrayOf(
        "ጃንዩወሪ", "ፌብሩወሪ", "ማርች", "ኤፕሪል", "ሜይ", "ጁን", "ጁላይ", "ኦገስት",
        "ሴፕቴምበር", "ኦክቶበር", "ኖቬምበር", "ዲሴምበር"
    )

    private fun key(c: Calendar) = String.format(
        Locale.US, "%04d%02d%02d", c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH)
    )

    private fun counts(raw: String?): Map<String, Int> =
        raw.orEmpty().split(",").mapNotNull {
            val p = it.split(":")
            if (p.size == 2) p[0] to (p[1].toIntOrNull() ?: 0) else null
        }.toMap()

    fun render(context: Context, glass: Boolean, widgetId: Int): RemoteViews {
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

        val eth = prefs.getString("eth", "0") == "1"
        val am = prefs.getString("lang", "en") == "am"
        // Calendar face: 0 Gregorian · 1 Ethiopian · 2 Islamic · 3 Orthodox.
        val face = faceOf(context, widgetId, eth)
        val faceDays = parseFaceDays(prefs.getString("face_days", ""))
        val faceToday = faceFor(prefs.getString("faces", ""), key(today), face)
        val todayEth = Ethiopian.fromCalendar(today)
        val fallbackMonth = when {
            (face == 1 || face == 3) && am -> Ethiopian.monthsAm[todayEth.second - 1]
            face == 1 || face == 3 -> Ethiopian.monthsEn[todayEth.second - 1]
            am -> gregAm[today.get(Calendar.MONTH)]
            else -> today.getDisplayName(Calendar.MONTH, Calendar.LONG, Locale.ENGLISH) ?: ""
        }
        fun dayOf(c: Calendar): Int {
            faceDays[key(c)]?.getOrNull(face)?.let { return it }
            return if (face == 1 || face == 3) Ethiopian.fromCalendar(c).third else c.get(Calendar.DAY_OF_MONTH)
        }
        val faceLabel = faceToday?.getOrNull(0) ?: arrayOf("Gregorian", "Ethiopian", "Islamic", "Orthodox")[face]
        val title = faceToday?.getOrNull(1) ?: fallbackMonth
        val dayText = faceToday?.getOrNull(2) ?: dayOf(today).toString()
        val faceLine = listOfNotNull(faceToday?.getOrNull(3), faceToday?.getOrNull(4))
            .filter { it.isNotEmpty() }.joinToString("  ·  ")
        val todayCount = byDay[key(today)] ?: 0
        val labelEvent = prefs.getString("label_event", "event") ?: "event"
        val labelEvents = prefs.getString("label_events", "events") ?: "events"

        if (glass) {
            views.setTextViewText(R.id.face_label, "⇄  $faceLabel")
            views.setTextViewText(R.id.month, title)
            views.setTextViewText(R.id.day, dayText)
            views.setTextViewText(R.id.face_line, faceLine)
            views.setTextViewText(R.id.add, prefs.getString("label_new", "＋ New Event"))
            val next = prefs.getString("next_title", "") ?: ""
            val whenText = prefs.getString("next_when", "") ?: ""
            val holiday = prefs.getString("holiday", "") ?: ""
            views.setTextViewText(
                R.id.next,
                when {
                    holiday.isNotEmpty() && next.isNotEmpty() -> "$holiday · $whenText $next"
                    holiday.isNotEmpty() -> holiday
                    next.isEmpty() -> prefs.getString("label_none", "No upcoming events") ?: ""
                    else -> "$whenText · $next"
                }
            )
        } else {
            views.setTextViewText(R.id.month, "⇄  $title")
            views.setTextViewText(
                R.id.day,
                "$todayCount ${if (todayCount == 1) labelEvent else labelEvents}"
            )
        }

        for (i in ids) {
            val d = start.clone() as Calendar
            d.add(Calendar.DAY_OF_MONTH, i)
            val idx = d.get(Calendar.DAY_OF_WEEK) - 1
            val isToday = key(d) == key(today)
            views.setTextViewText(
                wdIds[i],
                when {
                    glass && am -> lettersAm[idx]
                    glass -> letters[idx]
                    am -> shortAm[idx]
                    else -> shortNames[idx]
                }
            )
            views.setTextViewText(numIds[i], dayOf(d).toString())
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
                context, 100000 + widgetId, launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.root, pi)
        }
        // ⇄ cycles the calendar of *this* widget only.
        val cycle = Intent(
            context,
            if (glass) GlassWidgetProvider::class.java else IslandWidgetProvider::class.java
        ).setAction(ACTION_CYCLE_FACE)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            .setData(Uri.parse("glasscalendar://cycle/$widgetId")) // keeps each PendingIntent distinct
        views.setOnClickPendingIntent(
            if (glass) R.id.face_label else R.id.month,
            PendingIntent.getBroadcast(
                context, widgetId, cycle,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        )
        return views
    }

    /** "yyyymmdd:g,e,h,o;…" → day numbers per face. */
    private fun parseFaceDays(raw: String?): Map<String, List<Int>> =
        raw.orEmpty().split(";").mapNotNull {
            val p = it.split(":")
            if (p.size == 2) p[0] to p[1].split(",").map { n -> n.toIntOrNull() ?: 0 } else null
        }.toMap()

    /** Today's [label, title, day, line, line2] for [face] from the app's JSON. */
    private fun faceFor(raw: String?, day: String, face: Int): List<String>? = try {
        val arr = JSONObject(raw ?: "{}").optJSONArray(day)?.optJSONArray(face)
        arr?.let { a -> (0 until a.length()).map { a.optString(it) } }
    } catch (e: Exception) {
        null
    }

    private fun prefs(context: Context) = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

    /** Calendar face of one widget instance; new widgets start on the app's default. */
    fun faceOf(context: Context, widgetId: Int, eth: Boolean = false): Int {
        val p = prefs(context)
        p.getString("face_$widgetId", null)?.toIntOrNull()?.let { return it.coerceIn(0, 3) }
        val def = (p.getString("face", if (eth) "1" else "0") ?: "0").toIntOrNull()?.coerceIn(0, 3) ?: 0
        p.edit().putString("face_$widgetId", def.toString()).apply()
        return def
    }

    fun setFace(context: Context, widgetId: Int, face: Int) {
        prefs(context).edit().putString("face_$widgetId", (face.mod(4)).toString()).apply()
    }

    fun forget(context: Context, ids: IntArray) {
        val e = prefs(context).edit()
        for (id in ids) e.remove("face_$id")
        e.apply()
    }

    /** ⇄ tapped on one widget: advance only that widget. */
    fun cycleFace(context: Context, widgetId: Int, glass: Boolean) {
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return
        setFace(context, widgetId, faceOf(context, widgetId) + 1)
        AppWidgetManager.getInstance(context).updateAppWidget(widgetId, render(context, glass, widgetId))
    }

    fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for ((cls, glass) in listOf(GlassWidgetProvider::class.java to true, IslandWidgetProvider::class.java to false)) {
            for (id in manager.getAppWidgetIds(ComponentName(context, cls))) {
                manager.updateAppWidget(id, render(context, glass, id))
            }
        }
    }

    fun isGlass(context: Context, widgetId: Int): Boolean =
        AppWidgetManager.getInstance(context).getAppWidgetInfo(widgetId)?.provider?.className?.endsWith("GlassWidgetProvider") ?: true
}

const val ACTION_CYCLE_FACE = "com.kidyoh.glass_calendar.CYCLE_FACE"

class GlassWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) manager.updateAppWidget(id, WidgetRenderer.render(context, true, id))
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) = WidgetRenderer.forget(context, appWidgetIds)

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_CYCLE_FACE) {
            WidgetRenderer.cycleFace(context, intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID), true)
        } else {
            super.onReceive(context, intent)
        }
    }
}

class IslandWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) manager.updateAppWidget(id, WidgetRenderer.render(context, false, id))
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) = WidgetRenderer.forget(context, appWidgetIds)

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_CYCLE_FACE) {
            WidgetRenderer.cycleFace(context, intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID), false)
        } else {
            super.onReceive(context, intent)
        }
    }
}
