package org.pleasance.songgate

import io.flutter.embedding.android.FlutterActivity
import android.app.Person
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.drawable.Icon
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var ready = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val preferences = getSharedPreferences("musiclink", MODE_PRIVATE)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.musiclink.prototype/preferences").setMethodCallHandler { call, result ->
            when (call.method) {
                "getPreferences" -> result.success(mapOf("target" to preferences.getString("target", "appleMusic")))
                "getSocial" -> {
                    val social = preferences.getString("social", null)
                    // Friends saved before the share targets existed get theirs too
                    social?.let(::publishShortcuts)
                    result.success(social)
                }
                "setSocial" -> {
                    val social = call.arguments as String
                    preferences.edit().putString("social", social).apply()
                    publishShortcuts(social)
                    result.success(null)
                }
                "getTestMode" -> result.success(if (preferences.contains("testMode")) preferences.getBoolean("testMode", false) else null)
                "setTestMode" -> {
                    preferences.edit().putBoolean("testMode", call.arguments as Boolean).apply()
                    result.success(null)
                }
                "getLocale" -> result.success(preferences.getString("locale", null))
                "setLocale" -> {
                    preferences.edit().putString("locale", call.arguments as String).apply()
                    result.success(null)
                }
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

    // The shared text and, when a friend or group was tapped among the Direct Share
    // targets, its shortcut ID ("friend:<name>" or "group:<name>")
    private fun consumeSharedText(intent: Intent): Map<String, String?>? {
        if (intent.action != Intent.ACTION_SEND || intent.type != "text/plain") return null
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString() ?: return null
        val to = intent.getStringExtra(Intent.EXTRA_SHORTCUT_ID)
        intent.removeExtra(Intent.EXTRA_TEXT)
        // Recently used targets rank first in the share sheet
        if (to != null && Build.VERSION.SDK_INT >= 29) getSystemService(ShortcutManager::class.java)?.reportShortcutUsed(to)
        return mapOf("text" to text, "to" to to)
    }

    // Every friend and group as a Direct Share target, the same IDs as the iOS share sheet suggestions
    private fun publishShortcuts(json: String) {
        if (Build.VERSION.SDK_INT < 29) return
        val manager = getSystemService(ShortcutManager::class.java) ?: return
        val social = JSONObject(json)
        val targets = mutableListOf<Pair<String, List<String>>>()
        val groups = social.optJSONArray("groups")
        for (index in 0 until (groups?.length() ?: 0)) {
            val group = groups?.optJSONObject(index) ?: continue
            val members = group.optJSONArray("members") ?: continue
            targets += "group:${group.optString("name")}" to List(members.length()) { members.optString(it) }
        }
        val friends = social.optJSONArray("friends")
        for (index in 0 until (friends?.length() ?: 0)) {
            val name = friends?.optJSONObject(index)?.optString("name").orEmpty()
            if (name.isNotEmpty()) targets += "friend:$name" to listOf(name)
        }
        val shortcuts = targets.take(manager.maxShortcutCountPerActivity).mapIndexed { rank, (id, members) ->
            val label = id.substringAfter(':')
            ShortcutInfo.Builder(this, id)
                .setShortLabel(label)
                .setIcon(avatar(label))
                .setIntent(Intent(Intent.ACTION_MAIN, null, this, MainActivity::class.java))
                .setCategories(setOf("org.pleasance.songgate.FRIEND"))
                .setPersons(members.map { Person.Builder().setName(it).setKey("friend:$it").build() }.toTypedArray())
                .setLongLived(true)
                .setRank(rank)
                .build()
        }
        // Removed friends and groups leave the share sheet too, even where Android kept them
        val removed = manager.dynamicShortcuts.map { it.id } - shortcuts.map { it.id }.toSet()
        if (Build.VERSION.SDK_INT >= 30 && removed.isNotEmpty()) manager.removeLongLivedShortcuts(removed)
        manager.dynamicShortcuts = shortcuts
    }

    // The initial on a steady colour per name, the same as FriendAvatar in the app
    private fun avatar(name: String): Icon {
        val size = 216
        val hue = name.fold(7) { sum, unit -> (sum * 31 + unit.code) % 360 }.toFloat()
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(hsl(hue, 0.35f, 0.30f))
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = hsl(hue, 0.6f, 0.88f)
            textSize = size * 0.3f
            textAlign = Paint.Align.CENTER
            typeface = Typeface.DEFAULT_BOLD
        }
        val initial = name.codePointAt(0).let { String(Character.toChars(it)) }.uppercase()
        canvas.drawText(initial, size / 2f, size / 2f - (paint.descent() + paint.ascent()) / 2, paint)
        return Icon.createWithAdaptiveBitmap(bitmap)
    }

    private fun hsl(hue: Float, saturation: Float, lightness: Float): Int {
        val value = lightness + saturation * minOf(lightness, 1 - lightness)
        return Color.HSVToColor(floatArrayOf(hue, if (value == 0f) 0f else 2 * (1 - lightness / value), value))
    }
}
