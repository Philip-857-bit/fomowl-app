package com.fomowl.owllet

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.getSystemService
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
	private val cameraPermissionChannelName = "owllet/camera_permission"
	private val cameraPermissionRequestCode = 0xCA11
	private var pendingCameraPermissionResult: MethodChannel.Result? = null

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		ensureDefaultNotificationChannel()
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			cameraPermissionChannelName,
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"ensureCameraPermission" -> ensureCameraPermission(result)
				else -> result.notImplemented()
			}
		}
	}

	// Grant the in-app WebView's getUserMedia camera request only after the app
	// process actually holds the OS CAMERA permission. flutter_inappwebview's
	// onPermissionRequest grants the web origin but never requests the runtime
	// permission itself, so the first-time KYC user needs this prompt.
	private fun ensureCameraPermission(result: MethodChannel.Result) {
		if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
			== PackageManager.PERMISSION_GRANTED
		) {
			result.success(true)
			return
		}
		// Only one request can be in flight; resolve any stale caller as denied.
		pendingCameraPermissionResult?.success(false)
		pendingCameraPermissionResult = result
		ActivityCompat.requestPermissions(
			this,
			arrayOf(Manifest.permission.CAMERA),
			cameraPermissionRequestCode,
		)
	}

	override fun onRequestPermissionsResult(
		requestCode: Int,
		permissions: Array<out String>,
		grantResults: IntArray,
	) {
		super.onRequestPermissionsResult(requestCode, permissions, grantResults)
		if (requestCode != cameraPermissionRequestCode) {
			return
		}
		val granted = grantResults.isNotEmpty() &&
			grantResults[0] == PackageManager.PERMISSION_GRANTED
		pendingCameraPermissionResult?.success(granted)
		pendingCameraPermissionResult = null
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
