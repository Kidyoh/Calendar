package com.kidyoh.glass_calendar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject

/**
 * Renderer for the home-screen widgets. Every widget instance (appWidgetId)
 * keeps its own calendar face, view and style in SharedPreferences
 * (`face_<id>`, `view_<id>`, `style_<id>`).
 *
 * Dates are computed here from the system clock so widgets stay right across
 * midnight; Flutter (home_widget) supplies events, per-face day numbers,
 * month grids, holidays and translated labels.
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

/** What a widget is; each has its own provider, views and default style. */
enum class Kind(val views: List<String>, val defaultView: String, val defaultStyle: String, val usesFace: Boolean) {
    GLASS(listOf("auto", "week", "month", "agenda"), "auto", "glass", true),
    ISLAND(listOf("auto", "week", "month"), "auto", "dark", true),
    DATE(listOf("date"), "date", "glass", true),
    PROGRESS(listOf("day", "week", "month", "year"), "day", "dark", true),
    NEXT(listOf("next", "agenda"), "next", "dark", false),
    FEASTS(listOf("feasts"), "feasts", "light", false);

    val provider: Class<out AppWidgetProvider>
        get() = when (this) {
            GLASS -> GlassWidgetProvider::class.java
            ISLAND -> IslandWidgetProvider::class.java
            DATE -> DateWidgetProvider::class.java
            PROGRESS -> ProgressWidgetProvider::class.java
            NEXT -> NextWidgetProvider::class.java
            FEASTS -> FeastsWidgetProvider::class.java
        }
}

/** Colours and drawables of one style. */
private class Skin(
    val bg: Int, val pill: Int, val sel: Int,
    val fg: Int, val muted: Int, val selFg: Int, val track: Int,
    val feast: Int, val fast: Int, val islamic: Int,
) {
    companion object {
        fun of(style: String): Skin = when (style) {
            "light" -> Skin(
                R.drawable.light_bg, R.drawable.pill_light, R.drawable.sel_light,
                Color.parseColor("#FF111111"), Color.parseColor("#FF8A8A8A"), Color.WHITE, Color.parseColor("#FFE6E3DC"),
                Color.parseColor("#FFC98A2B"), Color.parseColor("#FF7D8A3E"), Color.parseColor("#FF3F8C86"),
            )
            "dark" -> Skin(
                R.drawable.island_bg, R.drawable.pill_dark, R.drawable.sel_glass,
                Color.WHITE, Color.parseColor("#FF9A9A9A"), Color.BLACK, Color.parseColor("#FF2E2E2E"),
                Color.parseColor("#FFF5C98A"), Color.parseColor("#FFC5CE9B"), Color.parseColor("#FF9ECBC7"),
            )
            else -> Skin(
                R.drawable.glass_bg, R.drawable.glass_pill, R.drawable.sel_glass,
                Color.WHITE, Color.parseColor("#B3FFFFFF"), Color.BLACK, Color.parseColor("#40FFFFFF"),
                Color.parseColor("#FFF5C98A"), Color.parseColor("#FFC5CE9B"), Color.parseColor("#FF9ECBC7"),
            )
        }
    }
}

private fun alpha(c: Int, a: Float) = Color.argb((Color.alpha(c) * a).toInt(), Color.red(c), Color.green(c), Color.blue(c))

private fun lerp(a: Int, b: Int, t: Float): Int {
    val k = t.coerceIn(0f, 1f)
    fun ch(x: Int, y: Int) = (x + (y - x) * k).toInt()
    return Color.argb(ch(Color.alpha(a), Color.alpha(b)), ch(Color.red(a), Color.red(b)), ch(Color.green(a), Color.green(b)), ch(Color.blue(a), Color.blue(b)))
}

object WidgetRenderer {
    private val wdIds = intArrayOf(R.id.wd0, R.id.wd1, R.id.wd2, R.id.wd3, R.id.wd4, R.id.wd5, R.id.wd6)
    private val numIds = intArrayOf(R.id.num0, R.id.num1, R.id.num2, R.id.num3, R.id.num4, R.id.num5, R.id.num6)
    private val dotIds = intArrayOf(R.id.dot0, R.id.dot1, R.id.dot2, R.id.dot3, R.id.dot4, R.id.dot5, R.id.dot6)
    private val cellIds = intArrayOf(
        R.id.c0, R.id.c1, R.id.c2, R.id.c3, R.id.c4, R.id.c5, R.id.c6, R.id.c7, R.id.c8, R.id.c9,
        R.id.c10, R.id.c11, R.id.c12, R.id.c13, R.id.c14, R.id.c15, R.id.c16, R.id.c17, R.id.c18, R.id.c19,
        R.id.c20, R.id.c21, R.id.c22, R.id.c23, R.id.c24, R.id.c25, R.id.c26, R.id.c27, R.id.c28, R.id.c29,
        R.id.c30, R.id.c31, R.id.c32, R.id.c33, R.id.c34, R.id.c35, R.id.c36, R.id.c37, R.id.c38, R.id.c39,
        R.id.c40, R.id.c41,
    )
    private val cellDotIds = intArrayOf(
        R.id.d0, R.id.d1, R.id.d2, R.id.d3, R.id.d4, R.id.d5, R.id.d6, R.id.d7, R.id.d8, R.id.d9,
        R.id.d10, R.id.d11, R.id.d12, R.id.d13, R.id.d14, R.id.d15, R.id.d16, R.id.d17, R.id.d18, R.id.d19,
        R.id.d20, R.id.d21, R.id.d22, R.id.d23, R.id.d24, R.id.d25, R.id.d26, R.id.d27, R.id.d28, R.id.d29,
        R.id.d30, R.id.d31, R.id.d32, R.id.d33, R.id.d34, R.id.d35, R.id.d36, R.id.d37, R.id.d38, R.id.d39,
        R.id.d40, R.id.d41,
    )
    private val rowIds = intArrayOf(R.id.r0, R.id.r1, R.id.r2, R.id.r3, R.id.r4, R.id.r5)
    private val agendaRows = intArrayOf(R.id.ar0, R.id.ar1, R.id.ar2, R.id.ar3, R.id.ar4, R.id.ar5)
    private val agendaBars = intArrayOf(R.id.ab0, R.id.ab1, R.id.ab2, R.id.ab3, R.id.ab4, R.id.ab5)
    private val agendaTimes = intArrayOf(R.id.at0, R.id.at1, R.id.at2, R.id.at3, R.id.at4, R.id.at5)
    private val agendaNames = intArrayOf(R.id.an0, R.id.an1, R.id.an2, R.id.an3, R.id.an4, R.id.an5)
    private val feastRows = intArrayOf(R.id.fr0, R.id.fr1, R.id.fr2, R.id.fr3, R.id.fr4)
    private val feastIcons = intArrayOf(R.id.fi0, R.id.fi1, R.id.fi2, R.id.fi3, R.id.fi4)
    private val feastNames = intArrayOf(R.id.fn0, R.id.fn1, R.id.fn2, R.id.fn3, R.id.fn4)
    private val feastWhens = intArrayOf(R.id.fw0, R.id.fw1, R.id.fw2, R.id.fw3, R.id.fw4)

    // Indexed by Calendar.DAY_OF_WEEK - 1 (Sunday first).
    private val letters = arrayOf("S", "M", "T", "W", "T", "F", "S")
    private val shortNames = arrayOf("Su", "Mo", "Tu", "We", "Th", "Fr", "Sa")
    private val threeNames = arrayOf("SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT")
    private val lettersAm = arrayOf("እ", "ሰ", "ማ", "ረ", "ሐ", "ዓ", "ቅ")
    private val shortAm = arrayOf("እሑ", "ሰኞ", "ማክ", "ረቡ", "ሐሙ", "ዓር", "ቅዳ")
    private val gregAm = arrayOf(
        "ጃንዩወሪ", "ፌብሩወሪ", "ማርች", "ኤፕሪል", "ሜይ", "ጁን", "ጁላይ", "ኦገስት",
        "ሴፕቴምበር", "ኦክቶበር", "ኖቬምበር", "ዲሴምበር"
    )
    private val faceNamesEn = arrayOf("Gregorian", "Ethiopian", "Islamic", "Orthodox")

    fun key(c: Calendar): String = String.format(
        Locale.US, "%04d%02d%02d", c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH)
    )

    private fun parseKey(k: String): Calendar? {
        if (k.length != 8) return null
        val c = Calendar.getInstance()
        c.clear()
        c.set(k.substring(0, 4).toInt(), k.substring(4, 6).toInt() - 1, k.substring(6, 8).toInt())
        return c
    }

    private fun startOfDay(c: Calendar): Calendar {
        val d = c.clone() as Calendar
        d.set(Calendar.HOUR_OF_DAY, 0); d.set(Calendar.MINUTE, 0); d.set(Calendar.SECOND, 0); d.set(Calendar.MILLISECOND, 0)
        return d
    }

    private fun plusDays(c: Calendar, n: Int): Calendar {
        val d = c.clone() as Calendar
        d.add(Calendar.DAY_OF_MONTH, n)
        return d
    }

    private fun daysBetween(a: Calendar, b: Calendar): Int =
        Math.round((startOfDay(b).timeInMillis - startOfDay(a).timeInMillis) / 86_400_000.0).toInt()

    private fun counts(raw: String?): Map<String, Int> =
        raw.orEmpty().split(",").mapNotNull {
            val p = it.split(":")
            if (p.size == 2) p[0] to (p[1].toIntOrNull() ?: 0) else null
        }.toMap()

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

    private fun jsonArray(raw: String?): JSONArray = try { JSONArray(raw ?: "[]") } catch (e: Exception) { JSONArray() }

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

    // ------------------------------------------------------------ per instance
    fun kindOf(context: Context, widgetId: Int): Kind {
        val cls = AppWidgetManager.getInstance(context).getAppWidgetInfo(widgetId)?.provider?.className ?: return Kind.GLASS
        return Kind.values().firstOrNull { cls.endsWith(it.provider.simpleName) } ?: Kind.GLASS
    }

    /** Calendar face of one widget instance; new widgets start on the app's default. */
    fun faceOf(context: Context, widgetId: Int, eth: Boolean = false): Int {
        val p = prefs(context)
        p.getString("face_$widgetId", null)?.toIntOrNull()?.let { return it.coerceIn(0, 3) }
        val def = (p.getString("face", if (eth) "1" else "0") ?: "0").toIntOrNull()?.coerceIn(0, 3) ?: 0
        p.edit().putString("face_$widgetId", def.toString()).apply()
        return def
    }

    fun viewOf(context: Context, widgetId: Int, kind: Kind): String {
        val v = prefs(context).getString("view_$widgetId", null)
        return if (v != null && v in kind.views) v else kind.defaultView
    }

    fun styleOf(context: Context, widgetId: Int, kind: Kind): String {
        val s = prefs(context).getString("style_$widgetId", null)
        return if (s == "glass" || s == "dark" || s == "light") s else kind.defaultStyle
    }

    fun setFace(context: Context, widgetId: Int, face: Int) {
        prefs(context).edit().putString("face_$widgetId", (face.mod(4)).toString()).apply()
    }

    fun setView(context: Context, widgetId: Int, view: String) {
        prefs(context).edit().putString("view_$widgetId", view).apply()
    }

    fun setStyle(context: Context, widgetId: Int, style: String) {
        prefs(context).edit().putString("style_$widgetId", style).apply()
    }

    fun forget(context: Context, ids: IntArray) {
        val e = prefs(context).edit()
        for (id in ids) {
            e.remove("face_$id"); e.remove("view_$id"); e.remove("style_$id")
        }
        e.apply()
    }

    /** ⇄ tapped on one widget: advance only that widget. */
    fun cycleFace(context: Context, widgetId: Int) {
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return
        setFace(context, widgetId, faceOf(context, widgetId) + 1)
        update(context, widgetId)
    }

    fun update(context: Context, widgetId: Int) {
        AppWidgetManager.getInstance(context).updateAppWidget(widgetId, render(context, widgetId))
    }

    fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for (k in Kind.values()) {
            for (id in manager.getAppWidgetIds(ComponentName(context, k.provider))) {
                manager.updateAppWidget(id, render(context, id, k))
            }
        }
    }

    /** Current height (dp) of a widget; used by "auto" to open up into a month. */
    private fun heightDp(context: Context, widgetId: Int): Int {
        val o: Bundle = AppWidgetManager.getInstance(context).getAppWidgetOptions(widgetId) ?: return 0
        return maxOf(o.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT), o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT))
    }

    // ----------------------------------------------------------------- render
    /** Everything the renderers share. */
    private class Ctx(val context: Context, val widgetId: Int, val kind: Kind) {
        val p = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val today: Calendar = Calendar.getInstance()
        val mondayFirst = p.getString("week_monday", "1") != "0"
        val byDay = counts(p.getString("counts", ""))
        val eth = p.getString("eth", "0") == "1"
        val am = p.getString("lang", "en") == "am"
        val face = faceOf(context, widgetId, eth)
        val skin = Skin.of(styleOf(context, widgetId, kind))
        val faceDays = parseFaceDays(p.getString("face_days", ""))
        val faceToday = faceFor(p.getString("faces", ""), key(today), face)
        val holDays = p.getString("hol_days", "").orEmpty().split(",").toSet()
        fun s(k: String, def: String) = p.getString(k, def) ?: def

        fun dayOf(c: Calendar): Int {
            faceDays[key(c)]?.getOrNull(face)?.let { return it }
            return if (face == 1 || face == 3) Ethiopian.fromCalendar(c).third else c.get(Calendar.DAY_OF_MONTH)
        }

        fun faceLabel(): String {
            faceToday?.getOrNull(0)?.let { return it }
            val names = s("face_names", "").split("|")
            return names.getOrNull(face)?.takeIf { it.isNotEmpty() } ?: faceNamesEn[face]
        }

        fun title(): String {
            faceToday?.getOrNull(1)?.let { return it }
            val e = Ethiopian.fromCalendar(today)
            return when {
                (face == 1 || face == 3) && am -> Ethiopian.monthsAm[e.second - 1]
                face == 1 || face == 3 -> Ethiopian.monthsEn[e.second - 1]
                am -> gregAm[today.get(Calendar.MONTH)]
                else -> today.getDisplayName(Calendar.MONTH, Calendar.LONG, Locale.ENGLISH) ?: ""
            }
        }

        fun weekStart(c: Calendar = today): Calendar {
            val start = startOfDay(c)
            val dow = start.get(Calendar.DAY_OF_WEEK) // 1 = Sunday
            start.add(Calendar.DAY_OF_MONTH, -(if (mondayFirst) (dow + 5) % 7 else dow - 1))
            return start
        }

        /** Month of [c] in this widget's calendar: (first day, length, title). */
        fun month(c: Calendar): Triple<Calendar, Int, String> {
            val k = key(c)
            val months = jsonArray(s("face_months", "[]")).optJSONArray(face)
            if (months != null) {
                for (i in 0 until months.length()) {
                    val m = months.optJSONArray(i) ?: continue
                    val start = parseKey(m.optString(0)) ?: continue
                    val len = m.optInt(1)
                    val end = plusDays(start, len)
                    if (k >= key(start) && k < key(end)) return Triple(start, len, m.optString(2))
                }
            }
            // No data from the app yet: compute Gregorian / Ethiopian natively.
            return if (face == 1 || face == 3) {
                val e = Ethiopian.fromCalendar(c)
                val start = plusDays(startOfDay(c), -(e.third - 1))
                val len = if (e.second < 13) 30 else (if (e.first % 4 == 3) 6 else 5)
                Triple(start, len, "${if (am) Ethiopian.monthsAm[e.second - 1] else Ethiopian.monthsEn[e.second - 1]} ${e.first}")
            } else {
                val start = startOfDay(c); start.set(Calendar.DAY_OF_MONTH, 1)
                Triple(start, c.getActualMaximum(Calendar.DAY_OF_MONTH), title())
            }
        }

        fun dayLabel(k: String): String {
            val d = parseKey(k) ?: return ""
            return when (daysBetween(today, d)) {
                0 -> s("label_today", "Today")
                1 -> s("label_tomorrow", "Tomorrow")
                else -> {
                    val idx = d.get(Calendar.DAY_OF_WEEK) - 1
                    "${if (am) shortAm[idx] else shortNames[idx]} ${dayOf(d)}"
                }
            }
        }

        fun inDays(n: Int): String = when {
            n <= 0 -> s("label_today_l", "today")
            n == 1 -> s("label_tomorrow_l", "tomorrow")
            else -> String.format(Locale.US, s("label_in_days", "in %d days"), n)
        }

        fun duration(mins: Long): String {
            val h = mins / 60
            val m = mins % 60
            val hl = s("label_h", "h")
            val ml = s("label_min", "m")
            return when {
                h == 0L -> "$m $ml"
                m == 0L -> "$h $hl"
                else -> "$h $hl $m $ml"
            }
        }
    }

    fun render(context: Context, widgetId: Int, kind: Kind = kindOf(context, widgetId)): RemoteViews {
        val c = Ctx(context, widgetId, kind)
        var view = viewOf(context, widgetId, kind)
        if (view == "auto") {
            val h = heightDp(context, widgetId)
            view = if (kind == Kind.GLASS && h >= 250 || kind == Kind.ISLAND && h >= 200) "month" else "week"
        }
        val views = when (kind) {
            Kind.GLASS, Kind.ISLAND -> when (view) {
                "month" -> month(c)
                "agenda" -> agenda(c, false)
                else -> week(c, kind == Kind.GLASS)
            }
            Kind.DATE -> date(c)
            Kind.PROGRESS -> progress(c, view)
            Kind.NEXT -> if (view == "agenda") agenda(c, true) else next(c)
            Kind.FEASTS -> feasts(c)
        }
        views.setInt(R.id.root, "setBackgroundResource", c.skin.bg)

        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launch != null) {
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
            val pi = PendingIntent.getActivity(
                context, 100000 + widgetId, launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.root, pi)
        }
        if (kind.usesFace) {
            // ⇄ cycles the calendar of *this* widget only.
            val cycle = Intent(context, kind.provider).setAction(ACTION_CYCLE_FACE)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                .setData(Uri.parse("glasscalendar://cycle/$widgetId")) // keeps each PendingIntent distinct
            val pi = PendingIntent.getBroadcast(
                context, widgetId, cycle,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val target = if (kind == Kind.ISLAND && view == "week") R.id.month else R.id.face_label
            views.setOnClickPendingIntent(target, pi)
        }
        return views
    }

    private fun chip(v: RemoteViews, c: Ctx) {
        v.setTextViewText(R.id.face_label, "⇄  ${c.faceLabel()}")
        v.setTextColor(R.id.face_label, c.skin.fg)
        v.setInt(R.id.face_label, "setBackgroundResource", c.skin.pill)
    }

    // ------------------------------------------------------------------- week
    private fun week(c: Ctx, glass: Boolean): RemoteViews {
        val v = RemoteViews(c.context.packageName, if (glass) R.layout.glass_widget else R.layout.island_widget)
        val sk = c.skin
        val dayText = c.faceToday?.getOrNull(2) ?: c.dayOf(c.today).toString()
        val todayCount = c.byDay[key(c.today)] ?: 0
        if (glass) {
            chip(v, c)
            v.setTextViewText(R.id.month, c.title())
            v.setTextViewText(R.id.day, dayText)
            val faceLine = listOfNotNull(c.faceToday?.getOrNull(3), c.faceToday?.getOrNull(4))
                .filter { it.isNotEmpty() }.joinToString("  ·  ")
            v.setTextViewText(R.id.face_line, faceLine)
            v.setTextViewText(R.id.add, c.s("label_new", "＋ New Event"))
            v.setInt(R.id.add, "setBackgroundResource", sk.pill)
            val next = c.s("next_title", "")
            val whenText = c.s("next_when", "")
            val holiday = c.s("holiday", "")
            v.setTextViewText(
                R.id.next,
                when {
                    holiday.isNotEmpty() && next.isNotEmpty() -> "$holiday · $whenText $next"
                    holiday.isNotEmpty() -> holiday
                    next.isEmpty() -> c.s("label_none", "No upcoming events")
                    else -> "$whenText · $next"
                }
            )
            for (id in intArrayOf(R.id.month, R.id.day, R.id.add)) v.setTextColor(id, sk.fg)
            v.setTextColor(R.id.face_line, alpha(sk.fg, .9f))
            v.setTextColor(R.id.next, alpha(sk.fg, .85f))
        } else {
            v.setTextViewText(R.id.month, "⇄  ${c.title()}")
            v.setTextViewText(
                R.id.day,
                "$todayCount ${if (todayCount == 1) c.s("label_event", "event") else c.s("label_events", "events")}"
            )
            v.setTextColor(R.id.month, sk.muted)
            v.setTextColor(R.id.day, sk.muted)
        }
        val start = c.weekStart()
        for (i in 0 until 7) {
            val d = plusDays(start, i)
            val idx = d.get(Calendar.DAY_OF_WEEK) - 1
            val isToday = key(d) == key(c.today)
            v.setTextViewText(
                wdIds[i],
                when {
                    glass && c.am -> lettersAm[idx]
                    glass -> letters[idx]
                    c.am -> shortAm[idx]
                    else -> shortNames[idx]
                }
            )
            v.setTextColor(wdIds[i], if (glass) sk.muted else sk.fg)
            v.setTextViewText(numIds[i], c.dayOf(d).toString())
            v.setTextColor(numIds[i], if (isToday) sk.selFg else sk.fg)
            v.setInt(numIds[i], "setBackgroundResource", if (isToday) (if (glass || sk.bg == R.drawable.light_bg) sk.sel else R.drawable.sel_island) else 0)
            val has = (c.byDay[key(d)] ?: 0) > 0
            val hol = key(d) in c.holDays
            v.setTextColor(dotIds[i], if (hol) sk.feast else if (has) alpha(sk.fg, .8f) else Color.TRANSPARENT)
        }
        return v
    }

    // ------------------------------------------------------------------ month
    private fun month(c: Ctx): RemoteViews {
        val v = RemoteViews(c.context.packageName, R.layout.widget_month)
        val sk = c.skin
        chip(v, c)
        val (first, len, title) = c.month(c.today)
        v.setTextViewText(R.id.title, title)
        v.setTextColor(R.id.title, sk.fg)
        var total = 0
        for (i in 0 until len) total += c.byDay[key(plusDays(first, i))] ?: 0
        v.setTextViewText(R.id.count, if (total == 0) "" else "$total ${if (total == 1) c.s("label_event", "event") else c.s("label_events", "events")}")
        v.setTextColor(R.id.count, sk.muted)

        val gridStart = c.weekStart(first)
        val lead = daysBetween(gridStart, first)
        val weeks = (lead + len + 6) / 7
        for (i in 0 until 7) {
            val idx = plusDays(gridStart, i).get(Calendar.DAY_OF_WEEK) - 1
            v.setTextViewText(wdIds[i], if (c.am) lettersAm[idx] else letters[idx])
            v.setTextColor(wdIds[i], sk.muted)
        }
        val todayKey = key(c.today)
        for (r in 0 until 6) v.setViewVisibility(rowIds[r], if (r < weeks) View.VISIBLE else View.GONE)
        for (i in 0 until 42) {
            if (i >= weeks * 7) continue
            val d = plusDays(gridStart, i)
            val k = key(d)
            val inMonth = i >= lead && i < lead + len
            val isToday = k == todayKey
            v.setTextViewText(cellIds[i], c.dayOf(d).toString())
            v.setTextColor(cellIds[i], if (isToday) sk.selFg else if (inMonth) sk.fg else alpha(sk.fg, .35f))
            v.setInt(cellIds[i], "setBackgroundResource", if (isToday) sk.sel else 0)
            val has = (c.byDay[k] ?: 0) > 0
            val hol = k in c.holDays
            v.setTextColor(
                cellDotIds[i],
                if (!inMonth) Color.TRANSPARENT else if (hol) sk.feast else if (has) alpha(sk.fg, .8f) else Color.TRANSPARENT
            )
        }
        return v
    }

    // ----------------------------------------------------------------- agenda
    private fun agenda(c: Ctx, nextKind: Boolean): RemoteViews {
        val v = RemoteViews(c.context.packageName, R.layout.widget_agenda)
        val sk = c.skin
        if (nextKind) {
            v.setViewVisibility(R.id.face_label, View.GONE)
            v.setTextViewText(R.id.title, c.s("label_agenda", "Agenda"))
        } else {
            chip(v, c)
            v.setTextViewText(R.id.title, c.title())
        }
        v.setTextColor(R.id.title, sk.fg)
        v.setTextColor(R.id.add, sk.fg)
        v.setInt(R.id.add, "setBackgroundResource", sk.pill)

        val now = System.currentTimeMillis()
        val todayKey = key(c.today)
        val all = jsonArray(c.s("agenda", "[]"))
        val items = (0 until all.length()).mapNotNull { all.optJSONArray(it) }.filter {
            val k = it.optString(0)
            val end = it.optLong(5)
            k >= todayKey && (it.optInt(6) == 1 || end > now)
        }
        val h = heightDp(c.context, c.widgetId)
        val max = if (h <= 0) 4 else ((h - 70) / 40).coerceIn(2, 6)
        v.setViewVisibility(R.id.empty, if (items.isEmpty()) View.VISIBLE else View.GONE)
        v.setTextViewText(R.id.empty, c.s("label_clear", "All clear — nothing coming up"))
        v.setTextColor(R.id.empty, sk.muted)
        for (i in 0 until 6) {
            val it = items.getOrNull(i)
            if (it == null || i >= max) {
                v.setViewVisibility(agendaRows[i], View.GONE); continue
            }
            v.setViewVisibility(agendaRows[i], View.VISIBLE)
            val color = try { Color.parseColor(it.optString(3)) } catch (e: Exception) { sk.fg }
            v.setInt(agendaBars[i], "setBackgroundColor", color)
            v.setTextViewText(agendaTimes[i], "${c.dayLabel(it.optString(0))} · ${it.optString(1)}")
            v.setTextViewText(agendaNames[i], it.optString(2))
            v.setTextColor(agendaTimes[i], sk.muted)
            v.setTextColor(agendaNames[i], sk.fg)
        }
        return v
    }

    // ------------------------------------------------------------------- date
    private fun date(c: Ctx): RemoteViews {
        val v = RemoteViews(c.context.packageName, R.layout.widget_date)
        val sk = c.skin
        chip(v, c)
        val idx = c.today.get(Calendar.DAY_OF_WEEK) - 1
        val holiday = c.s("holiday", "")
        v.setTextViewText(R.id.wd, if (c.am) shortAm[idx] else threeNames[idx])
        v.setTextColor(R.id.wd, if (holiday.isNotEmpty()) Color.parseColor("#FFE08A84") else sk.muted)
        v.setTextViewText(R.id.day, c.faceToday?.getOrNull(2) ?: c.dayOf(c.today).toString())
        v.setTextViewText(R.id.title, c.title())
        v.setTextViewText(R.id.line, if (holiday.isNotEmpty()) holiday else c.faceToday?.getOrNull(3).orEmpty())
        v.setTextViewText(R.id.line2, c.faceToday?.getOrNull(4).orEmpty())
        v.setTextColor(R.id.day, sk.fg)
        v.setTextColor(R.id.title, sk.fg)
        v.setTextColor(R.id.line, alpha(sk.fg, .88f))
        v.setTextColor(R.id.line2, sk.muted)
        return v
    }

    // --------------------------------------------------------------- progress
    private fun progress(c: Ctx, view: String): RemoteViews {
        val v = RemoteViews(c.context.packageName, R.layout.widget_progress)
        val sk = c.skin
        chip(v, c)
        val now = Calendar.getInstance()
        val today = startOfDay(now)
        val minsToday = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        var units: Int
        var perRow: Int
        var frac: Float
        val title: String
        val left: String
        val daysLeft = c.s("label_days_left", "%d days left")
        when (view) {
            "week" -> {
                val s = c.weekStart()
                val gone = daysBetween(s, today)
                frac = (gone * 1440 + minsToday) / (7f * 1440)
                units = 7; perRow = 7
                val iso = Calendar.getInstance().apply {
                    firstDayOfWeek = Calendar.MONDAY; minimalDaysInFirstWeek = 4; timeInMillis = now.timeInMillis
                }.get(Calendar.WEEK_OF_YEAR)
                title = "${c.s("label_week", "Week")} $iso"
                left = String.format(Locale.US, daysLeft, 6 - gone)
            }
            "month" -> {
                val (first, len, t) = c.month(today)
                val gone = daysBetween(first, today)
                frac = (gone * 1440 + minsToday) / (len * 1440f)
                units = len; perRow = (len + 1) / 2
                title = t
                left = String.format(Locale.US, daysLeft, len - gone - 1)
            }
            "year" -> {
                val y = jsonArray(c.s("face_years", "[]")).optJSONArray(c.face)
                val ys = y?.let { parseKey(it.optString(0)) }
                val ye = y?.let { parseKey(it.optString(1)) }
                if (ys != null && ye != null && !today.before(ys) && today.before(ye)) {
                    val days = daysBetween(ys, ye)
                    val gone = daysBetween(ys, today)
                    frac = (gone * 1440 + minsToday) / (days * 1440f)
                    units = y.optInt(3, 12)
                    title = y.optString(2)
                    left = String.format(Locale.US, daysLeft, days - gone - 1)
                } else {
                    val days = today.getActualMaximum(Calendar.DAY_OF_YEAR)
                    val gone = today.get(Calendar.DAY_OF_YEAR) - 1
                    frac = (gone * 1440 + minsToday) / (days * 1440f)
                    units = 12
                    title = today.get(Calendar.YEAR).toString()
                    left = String.format(Locale.US, daysLeft, days - gone - 1)
                }
                perRow = units
            }
            else -> {
                frac = minsToday / 1440f
                units = 24; perRow = 12
                title = c.s("label_day", "Day")
                left = String.format(Locale.US, c.s("label_left", "%s left").replace("%s", "%1\$s"), c.duration((1440 - minsToday).toLong()))
            }
        }
        frac = frac.coerceIn(0f, 1f)
        v.setTextViewText(R.id.title, title)
        v.setTextViewText(R.id.pct, "${Math.round(frac * 100)}%")
        v.setTextViewText(R.id.left, left)
        v.setTextColor(R.id.title, sk.fg)
        v.setTextColor(R.id.pct, sk.fg)
        v.setTextColor(R.id.left, sk.muted)
        v.setImageViewBitmap(R.id.dots, dots(units, frac * units, perRow, sk))
        return v
    }

    /** Rows of dots filling up from the track colour to the text colour. */
    private fun dots(units: Int, lit: Float, perRow: Int, sk: Skin): Bitmap {
        val w = 720
        val gap = 10f
        val d = minOf(46f, (w - gap * (perRow - 1)) / perRow)
        val rows = (units + perRow - 1) / perRow
        val h = (rows * d + (rows - 1) * gap * 1.4f).toInt().coerceAtLeast(1)
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val cv = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val spread = (w - d) / maxOf(1, perRow - 1)
        for (i in 0 until units) {
            val r = i / perRow
            val col = i % perRow
            val x = if (perRow == 1) w / 2f else d / 2 + col * spread
            val y = d / 2 + r * (d + gap * 1.4f)
            paint.color = lerp(sk.track, sk.fg, lit - i)
            cv.drawCircle(x, y, d / 2, paint)
        }
        return bmp
    }

    // ------------------------------------------------------------------- next
    private fun next(c: Ctx): RemoteViews {
        val v = RemoteViews(c.context.packageName, R.layout.widget_next)
        val sk = c.skin
        val now = System.currentTimeMillis()
        val all = jsonArray(c.s("agenda", "[]"))
        val e = (0 until all.length()).mapNotNull { all.optJSONArray(it) }
            .firstOrNull { it.optInt(6) == 0 && it.optLong(5) > now }
        v.setTextViewText(R.id.head, c.s("label_next", "Next up"))
        v.setTextColor(R.id.head, sk.muted)
        v.setTextColor(R.id.countdown, sk.muted)
        v.setTextColor(R.id.title, sk.fg)
        v.setTextColor(R.id.time, sk.muted)
        if (e == null) {
            v.setTextViewText(R.id.countdown, "")
            v.setTextViewText(R.id.title, c.s("label_clear", "All clear — nothing coming up"))
            v.setTextViewText(R.id.time, "")
            v.setViewVisibility(R.id.bar, View.GONE)
            return v
        }
        val start = e.optLong(4)
        val end = e.optLong(5)
        val started = start <= now
        v.setTextViewText(
            R.id.countdown,
            if (started) c.s("label_now", "happening now")
            else String.format(Locale.US, c.s("label_in", "in %s").replace("%s", "%1\$s"), c.duration((start - now) / 60000 + 1))
        )
        v.setTextViewText(R.id.title, e.optString(2))
        val endCal = Calendar.getInstance().apply { timeInMillis = end }
        val endText = String.format(Locale.US, "%d:%02d", endCal.get(Calendar.HOUR_OF_DAY), endCal.get(Calendar.MINUTE))
        v.setTextViewText(R.id.time, "${c.dayLabel(e.optString(0))} · ${e.optString(1)} – $endText")
        val frac = if (started) ((now - start).toFloat() / maxOf(1L, end - start)).coerceIn(0f, 1f) else 0f
        v.setViewVisibility(R.id.bar, View.VISIBLE)
        v.setImageViewBitmap(R.id.bar, bar(frac, sk, try { Color.parseColor(e.optString(3)) } catch (x: Exception) { sk.fg }))
        return v
    }

    private fun bar(frac: Float, sk: Skin, accent: Int): Bitmap {
        val w = 720
        val h = 16
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val cv = Canvas(bmp)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.color = sk.track
        cv.drawRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), h / 2f, h / 2f, p)
        if (frac > 0f) {
            p.color = sk.fg
            cv.drawRoundRect(RectF(0f, 0f, maxOf(h.toFloat(), w * frac), h.toFloat()), h / 2f, h / 2f, p)
        } else {
            p.color = accent
            cv.drawCircle(h / 2f, h / 2f, h / 2f, p)
        }
        return bmp
    }

    // ----------------------------------------------------------------- feasts
    private fun feasts(c: Ctx): RemoteViews {
        val v = RemoteViews(c.context.packageName, R.layout.widget_feasts)
        val sk = c.skin
        v.setTextViewText(R.id.title, "✝  ${c.s("label_feasts", "Feasts & fasts")}")
        v.setTextColor(R.id.title, sk.fg)
        val todayKey = key(c.today)
        val fast = c.s("fasts", "").split(";").firstOrNull { it.startsWith("$todayKey=") }?.substringAfter("=")
        v.setTextViewText(R.id.fast, "🌿  ${fast ?: c.s("label_no_fast", "No fast today")}")
        v.setTextColor(R.id.fast, sk.fast)
        v.setInt(R.id.fast, "setBackgroundResource", sk.pill)

        val all = jsonArray(c.s("feasts", "[]"))
        val items = (0 until all.length()).mapNotNull { all.optJSONArray(it) }.filter { it.optString(0) >= todayKey }
        val h = heightDp(c.context, c.widgetId)
        val max = if (h <= 0) 4 else ((h - 80) / 26).coerceIn(1, 5)
        for (i in 0 until 5) {
            val it = items.getOrNull(i)
            if (it == null || i >= max) {
                v.setViewVisibility(feastRows[i], View.GONE); continue
            }
            v.setViewVisibility(feastRows[i], View.VISIBLE)
            val kind = it.optString(2)
            val dayOff = it.optInt(3) == 1
            v.setTextViewText(feastIcons[i], if (kind == "islamic") "☪" else if (kind == "national") "★" else "✦")
            v.setTextColor(
                feastIcons[i],
                if (kind == "islamic") sk.islamic else if (dayOff) Color.parseColor("#FFE08A84") else sk.feast
            )
            v.setTextViewText(feastNames[i], it.optString(1))
            v.setTextColor(feastNames[i], sk.fg)
            val d = parseKey(it.optString(0))
            v.setTextViewText(feastWhens[i], if (d == null) "" else c.inDays(daysBetween(c.today, d)))
            v.setTextColor(feastWhens[i], sk.muted)
        }
        return v
    }
}

const val ACTION_CYCLE_FACE = "com.kidyoh.glass_calendar.CYCLE_FACE"

/** One provider per widget kind; each widget instance renders on its own. */
abstract class CalendarWidgetProvider(private val kind: Kind) : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) manager.updateAppWidget(id, WidgetRenderer.render(context, id, kind))
    }

    /** Resized: "auto" widgets open up into a month; lists show more rows. */
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, appWidgetId: Int, newOptions: Bundle) {
        manager.updateAppWidget(appWidgetId, WidgetRenderer.render(context, appWidgetId, kind))
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) = WidgetRenderer.forget(context, appWidgetIds)

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_CYCLE_FACE) {
            WidgetRenderer.cycleFace(context, intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID))
        } else {
            super.onReceive(context, intent)
        }
    }
}

class GlassWidgetProvider : CalendarWidgetProvider(Kind.GLASS)
class IslandWidgetProvider : CalendarWidgetProvider(Kind.ISLAND)
class DateWidgetProvider : CalendarWidgetProvider(Kind.DATE)
class ProgressWidgetProvider : CalendarWidgetProvider(Kind.PROGRESS)
class NextWidgetProvider : CalendarWidgetProvider(Kind.NEXT)
class FeastsWidgetProvider : CalendarWidgetProvider(Kind.FEASTS)
