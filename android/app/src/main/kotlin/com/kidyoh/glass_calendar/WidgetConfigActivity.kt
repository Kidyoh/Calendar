package com.kidyoh.glass_calendar

import android.app.Activity
import android.app.AlertDialog
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.os.Bundle
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.ScrollView
import android.widget.TextView
import java.util.Calendar
import java.util.Locale
import org.json.JSONObject

/**
 * Shown when a widget is added (and on "Reconfigure" on Android 12+):
 * pick this particular widget's calendar, what it shows and its style.
 */
class WidgetConfigActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val id = intent?.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        // Until the user confirms, adding the widget is cancelled.
        setResult(RESULT_CANCELED, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id))
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish(); return
        }

        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val am = prefs.getString("lang", "en") == "am"
        val kind = WidgetRenderer.kindOf(this, id)

        val faceNames = if (am) arrayOf("ግሪጎሪያን", "ኢትዮጵያዊ", "የሂጅራ", "ኦርቶዶክስ")
        else arrayOf("Gregorian", "Ethiopian", "Islamic", "Orthodox")
        // Preview today's date in each calendar when the app has provided it.
        val now = Calendar.getInstance()
        val key = String.format(Locale.US, "%04d%02d%02d", now.get(Calendar.YEAR), now.get(Calendar.MONTH) + 1, now.get(Calendar.DAY_OF_MONTH))
        val today = try { JSONObject(prefs.getString("faces", "{}") ?: "{}").optJSONArray(key) } catch (e: Exception) { null }
        val faceItems = faceNames.mapIndexed { i, n ->
            val f = today?.optJSONArray(i)
            if (f == null) n else "$n  ·  ${f.optString(1)} ${f.optString(2)}"
        }
        val viewNames = mapOf(
            "auto" to if (am) "ራስ-ሰር (ሲረዝም ወር)" else "Auto (month when tall)",
            "week" to if (am) "ሳምንት" else "Week",
            "month" to if (am) "ወር" else "Month",
            "agenda" to if (am) "አጀንዳ" else "Agenda",
            "day" to if (am) "ቀን" else "Day",
            "year" to if (am) "ዓመት" else "Year",
            "next" to if (am) "ቀጣይ" else "Next up",
        )
        val styles = listOf("glass", "dark", "light")
        val styleNames = if (am) listOf("መስታወት", "ጨለማ", "ብሩህ") else listOf("Glass", "Dark", "Light")

        var face = WidgetRenderer.faceOf(this, id, prefs.getString("eth", "0") == "1")
        var view = WidgetRenderer.viewOf(this, id, kind)
        var style = WidgetRenderer.styleOf(this, id, kind)

        val dp = resources.displayMetrics.density
        val body = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((22 * dp).toInt(), (6 * dp).toInt(), (22 * dp).toInt(), 0)
        }
        fun header(text: String) = body.addView(TextView(this).apply {
            this.text = text
            setTypeface(typeface, Typeface.BOLD)
            textSize = 13f
            alpha = .6f
            setPadding(0, (14 * dp).toInt(), 0, (2 * dp).toInt())
        })
        fun group(items: List<String>, selected: Int, horizontal: Boolean, onPick: (Int) -> Unit) {
            val g = RadioGroup(this).apply { orientation = if (horizontal) RadioGroup.HORIZONTAL else RadioGroup.VERTICAL }
            items.forEachIndexed { i, label ->
                g.addView(
                    RadioButton(this).apply {
                        this.id = 1000 + i
                        text = label
                        isChecked = i == selected
                        setPadding(0, 0, (10 * dp).toInt(), 0)
                    },
                    RadioGroup.LayoutParams(
                        if (horizontal) 0 else ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT,
                        if (horizontal) 1f else 0f,
                    )
                )
            }
            g.setOnCheckedChangeListener { _, checked -> onPick(checked - 1000) }
            body.addView(g)
        }

        if (kind.usesFace) {
            header(if (am) "ቀን መቁጠሪያ" else "Calendar")
            group(faceItems, face, false) { face = it }
        }
        if (kind.views.size > 1) {
            header(if (am) "አሳይ" else "Show")
            group(kind.views.map { viewNames[it] ?: it }, kind.views.indexOf(view), false) { view = kind.views[it] }
        }
        header(if (am) "ዘይቤ" else "Style")
        group(styleNames, styles.indexOf(style), true) { style = styles[it] }

        AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Light_Dialog_Alert)
            .setTitle(if (am) "ዊጀቱን ያብጁ" else "Customize widget")
            .setView(ScrollView(this).apply { addView(body) })
            .setPositiveButton(if (am) "ተጠናቋል" else "Done") { _, _ ->
                WidgetRenderer.setFace(this, id, face)
                WidgetRenderer.setView(this, id, view)
                WidgetRenderer.setStyle(this, id, style)
                WidgetRenderer.update(this, id)
                setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id))
                finish()
            }
            .setNegativeButton(if (am) "ሰርዝ" else "Cancel") { _, _ -> finish() }
            .setOnCancelListener { finish() }
            .show()
    }
}
