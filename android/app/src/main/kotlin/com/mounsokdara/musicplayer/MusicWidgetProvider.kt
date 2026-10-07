package com.mounsokdara.musicplayer

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.KeyEvent
import android.widget.RemoteViews

/**
 * Home-screen playback widgets (§6.11).
 *
 * Controls are delivered as media button events to the audio_service media
 * session, so the widget stays in sync with the notification and the app.
 */
abstract class MusicWidgetProvider(private val layoutId: Int) : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, layoutId)

            views.setOnClickPendingIntent(R.id.widget_prev, mediaButton(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS))
            views.setOnClickPendingIntent(R.id.widget_play, mediaButton(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
            views.setOnClickPendingIntent(R.id.widget_next, mediaButton(context, KeyEvent.KEYCODE_MEDIA_NEXT))

            val open = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            views.setOnClickPendingIntent(R.id.widget_root, open)

            manager.updateAppWidget(id, views)
        }
    }

    private fun mediaButton(context: Context, keyCode: Int): PendingIntent {
        val intent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            component = ComponentName(
                context,
                com.ryanheise.audioservice.MediaButtonReceiver::class.java
            )
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        }
        return PendingIntent.getBroadcast(
            context,
            keyCode,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }
}

/** Small 2x1 widget: previous / play-pause / next. */
class MusicWidgetProviderSmall : MusicWidgetProvider(R.layout.music_widget_small)

/** Medium 4x2 widget: artwork, title/artist, transport controls. */
class MusicWidgetProviderMedium : MusicWidgetProvider(R.layout.music_widget_medium)
