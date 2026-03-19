package com.fomowl.owllet

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import androidx.core.content.getSystemService
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		ensureDefaultNotificationChannel()
	}

	private fun ensureDefaultNotificationChannel() {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
			return
		}

		val manager = applicationContext.getSystemService<NotificationManager>() ?: return
		val channelId = getString(R.string.default_notification_channel_id)
		val channelName = getString(R.string.default_notification_channel_name)
		val existing = manager.getNotificationChannel(channelId)
		if (existing != null) {
			return
		}

		val channel = NotificationChannel(
			channelId,
			channelName,
			NotificationManager.IMPORTANCE_DEFAULT,
		).apply {
			description = "General Owllet notifications"
		}
		manager.createNotificationChannel(channel)
	}
}
