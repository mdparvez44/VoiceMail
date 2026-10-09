
package com.parvez.personalbutler.personal_buttler

import android.content.ComponentName
import android.content.Context
import android.service.quicksettings.TileService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "personal_butler/settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->

            val prefs = getSharedPreferences(
                "personal_butler",
                Context.MODE_PRIVATE
            )

            when (call.method) {
"setCustomMessage" -> {
    val message = call.argument<String>("message") ?: ""
    prefs.edit().putString("customMessage", message).apply()
    result.success(true)
}
                
"getSettings" -> {
    result.success(
        mapOf(
            "enabled" to prefs.getBoolean("enabled", false),
            "mode" to prefs.getString("mode", "General"),
            "customMessage" to prefs.getString(
                "customMessage",
                "I'm currently unavailable. Please leave a message."
            )
        )
    )
}

                "setEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    prefs.edit().putBoolean("enabled", enabled).apply()

                    TileService.requestListeningState(
                        this,
                        ComponentName(this, ButlerTileService::class.java)
                    )
                    result.success(true)
                }

                "setMode" -> {
                    val mode = call.argument<String>("mode") ?: "General"
                    prefs.edit().putString("mode", mode).apply()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }
}
