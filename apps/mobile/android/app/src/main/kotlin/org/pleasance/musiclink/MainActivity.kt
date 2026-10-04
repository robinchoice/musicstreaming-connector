package org.pleasance.musiclink

import io.flutter.embedding.android.FlutterActivity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var ready = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val preferences = getSharedPreferences("musiclink", MODE_PRIVATE)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.musiclink.prototype/preferences").setMethodCallHandler { call, result ->
            when (call.method) {
                "getPreferences" -> result.success(mapOf("target" to preferences.getString("target", "appleMusic")))
                "setPreferences" -> {
                    preferences.edit().putString("target", call.argument<String>("target")).apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.musiclink.prototype/share")
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "getSharedText") {
                ready = true
                result.success(consumeSharedText(intent))
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (ready) consumeSharedText(intent)?.let { channel?.invokeMethod("sharedText", it) }
    }

    private fun consumeSharedText(intent: Intent): String? {
        if (intent.action != Intent.ACTION_SEND || intent.type != "text/plain") return null
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
        intent.removeExtra(Intent.EXTRA_TEXT)
        return text
    }
}
