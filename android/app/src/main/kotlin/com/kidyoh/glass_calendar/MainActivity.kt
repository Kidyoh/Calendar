package com.kidyoh.glass_calendar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "glass_calendar/widgets")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pin" -> result.success(
                        pinWidget(
                            call.argument<String>("type") ?: "glass",
                            call.argument<Int>("face") ?: 0,
                            call.argument<String>("view") ?: "",
                            call.argument<String>("style") ?: "",
                        )
                    )
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Puts a widget on the home screen already set up like the one in the app:
     * same calendar, view and style. Returns "requested" or "unsupported".
     * Either way the settings are remembered for a few minutes, so a widget of
     * this kind added by hand from the widget picker starts with them too.
     */
    private fun pinWidget(type: String, face: Int, view: String, style: String): String {
        val kind = Kind.values().firstOrNull { it.name.equals(type, ignoreCase = true) } ?: Kind.GLASS
        val pending = JSONObject()
            .put("kind", kind.name).put("face", face).put("view", view).put("style", style)
            .put("at", System.currentTimeMillis())
        getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            .edit().putString("pin_pending", pending.toString()).apply()

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return "unsupported"
        val manager = AppWidgetManager.getInstance(this)
        if (!manager.isRequestPinAppWidgetSupported) return "unsupported"
        // The launcher adds EXTRA_APPWIDGET_ID to this intent once the widget lands.
        val done = Intent(this, kind.provider).setAction(ACTION_PINNED)
            .putExtra("face", face).putExtra("view", view).putExtra("style", style)
            .setData(Uri.parse("glasscalendar://pinned/${System.currentTimeMillis()}"))
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
        val callback = PendingIntent.getBroadcast(this, 7000 + kind.ordinal, done, flags)
        return if (manager.requestPinAppWidget(ComponentName(this, kind.provider), null, callback)) "requested" else "unsupported"
    }
}
