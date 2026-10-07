package com.mounsokdara.musicplayer

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter app and forwards incoming audio ACTION_VIEW / ACTION_SEND
 * intents to Dart, which opens the lightweight floating player (§6.10).
 */
class MainActivity : FlutterActivity() {

    private val channel = "com.mounsokdara.musicplayer/intents"
    private var methodChannel: MethodChannel? = null
    private var pendingUri: String? = null

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
