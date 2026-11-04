package com.mounsokdara.musicplayer

import android.content.Intent
import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter app and forwards incoming audio ACTION_VIEW / ACTION_SEND
 * intents to Dart, which opens the lightweight floating player (§6.10).
 */
class MainActivity : AudioServiceActivity() {

    private val channel = "com.mounsokdara.musicplayer/intents"
    private val eqChannel = "com.mounsokdara.musicplayer/equalizer"
    private var methodChannel: MethodChannel? = null
    private var pendingUri: String? = null
    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialAudio" -> {
                    result.success(pendingUri ?: uriFrom(intent))
                    pendingUri = null
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, eqChannel)
            .setMethodCallHandler { call, result -> handleEqualizer(call, result) }
    }

    private fun handleEqualizer(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "init" -> {
                    val sessionId = (call.argument<Int>("sessionId")) ?: 0
                    equalizer?.release()
                    bassBoost?.release()
                    equalizer = Equalizer(0, sessionId).apply { enabled = true }
                    bassBoost = BassBoost(0, sessionId).apply { enabled = true }
                    val eq = equalizer!!
                    val range = eq.bandLevelRange
                    val bands = (0 until eq.numberOfBands).map { eq.getCenterFreq(it.toShort()) }
                    val presets = (0 until eq.numberOfPresets).map { eq.getPresetName(it.toShort()) }
                    result.success(mapOf(
                        "bands" to bands,
                        "min" to range[0].toInt(),
                        "max" to range[1].toInt(),
                        "presets" to presets,
                    ))
                }
                "setEnabled" -> {
                    val on = call.argument<Boolean>("enabled") ?: true
                    equalizer?.enabled = on
                    bassBoost?.enabled = on
                    result.success(null)
                }
                "setBandLevel" -> {
                    val band = call.argument<Int>("band") ?: 0
                    val level = call.argument<Int>("level") ?: 0
                    equalizer?.setBandLevel(band.toShort(), level.toShort())
                    result.success(null)
                }
                "setPreset" -> {
                    val preset = call.argument<Int>("preset") ?: 0
                    equalizer?.usePreset(preset.toShort())
                    result.success(null)
                }
                "setBassBoost" -> {
                    val strength = call.argument<Int>("strength") ?: 0
                    bassBoost?.setStrength(strength.toShort())
                    result.success(null)
                }
                "release" -> {
                    equalizer?.release(); equalizer = null
                    bassBoost?.release(); bassBoost = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("equalizer", e.message, null)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val uri = uriFrom(intent) ?: return
        if (methodChannel == null) pendingUri = uri
        else methodChannel?.invokeMethod("openAudio", uri)
    }

    private fun uriFrom(intent: Intent?): String? {
        intent ?: return null
        return when (intent.action) {
            Intent.ACTION_VIEW -> intent.data?.toString()
            Intent.ACTION_SEND -> intent.getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM)?.toString()
            else -> null
        }
    }
}
