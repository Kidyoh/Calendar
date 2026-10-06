package com.kidyoh.glass_calendar

import android.app.Activity
import android.app.AlertDialog
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import java.util.Calendar
import java.util.Locale
import org.json.JSONObject

/**
 * Shown when a widget is added (and on "Reconfigure" on Android 12+):
 * pick which calendar this particular widget shows.
 */
class WidgetConfigActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val id = intent?.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        // Until the user picks, adding the widget is cancelled.
        setResult(RESULT_CANCELED, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id))
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish(); return
        }

        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val am = prefs.getString("lang", "en") == "am"
        val names = if (am) arrayOf("ግሪጎሪያን", "ኢትዮጵያዊ", "የሂጅራ", "ኦርቶዶክስ")
        else arrayOf("Gregorian", "Ethiopian", "Islamic", "Orthodox")
        // Preview today's date in each calendar when the app has provided it.
        val now = Calendar.getInstance()
        val key = String.format(Locale.US, "%04d%02d%02d", now.get(Calendar.YEAR), now.get(Calendar.MONTH) + 1, now.get(Calendar.DAY_OF_MONTH))
        val today = try { JSONObject(prefs.getString("faces", "{}") ?: "{}").optJSONArray(key) } catch (e: Exception) { null }
        val items = names.mapIndexed { i, n ->
            val f = today?.optJSONArray(i)
            if (f == null) n else "$n  ·  ${f.optString(1)} ${f.optString(2)}"
        }.toTypedArray()
        val current = WidgetRenderer.faceOf(this, id, prefs.getString("eth", "0") == "1")

        AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Light_Dialog_Alert)
            .setTitle(if (am) "ቀን መቁጠሪያ ይምረጡ" else "Choose a calendar")
            .setSingleChoiceItems(items, current) { dialog, which ->
                WidgetRenderer.setFace(this, id, which)
                val glass = WidgetRenderer.isGlass(this, id)
                AppWidgetManager.getInstance(this).updateAppWidget(id, WidgetRenderer.render(this, glass, id))
                setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id))
                dialog.dismiss()
                finish()
            }
            .setOnCancelListener { finish() }
            .show()
    }
}
