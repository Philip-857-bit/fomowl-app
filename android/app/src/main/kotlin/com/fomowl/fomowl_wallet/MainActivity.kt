package com.fomowl.owllet

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentValues
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.util.Base64
import android.util.Log
import androidx.activity.enableEdgeToEdge
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.core.content.getSystemService
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
	private val logTag = "OwlletReceipt"
	private val cameraPermissionChannelName = "owllet/camera_permission"
	private val receiptFilesChannelName = "owllet/receipt_files"
	private val cameraPermissionRequestCode = 0xCA11
	private var pendingCameraPermissionResult: MethodChannel.Result? = null

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		// Android 15+ enforces edge-to-edge for modern targets. Enable it on
		// earlier versions too, so the Flutter SafeAreas behave consistently.
		enableEdgeToEdge()
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
		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			receiptFilesChannelName,
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"saveReceiptImage" -> saveReceiptImage(call.arguments, result)
				"shareReceiptImage" -> shareReceiptImage(call.arguments, result)
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

	private fun receiptBytes(arguments: Any?): Pair<String, ByteArray>? {
		val args = arguments as? Map<*, *> ?: return null
		val rawName = args["filename"]?.toString()?.takeIf { it.isNotBlank() } ?: "owllet-receipt"
		val safeName = rawName.replace(Regex("[^A-Za-z0-9._-]"), "-").trim('-').ifBlank {
			"owllet-receipt"
		}
		val dataUrl = args["dataUrl"]?.toString() ?: return null
		val marker = "base64,"
		val markerIndex = dataUrl.indexOf(marker)
		if (!dataUrl.startsWith("data:image/png") || markerIndex < 0) {
			return null
		}
		val encoded = dataUrl.substring(markerIndex + marker.length)
		val bytes = Base64.decode(encoded, Base64.DEFAULT)
		return Pair(safeName, bytes)
	}

	private fun saveReceiptImage(arguments: Any?, result: MethodChannel.Result) {
		val parsed = receiptBytes(arguments)
		if (parsed == null) {
			result.success(mapOf(
				"ok" to false,
				"code" to "RECEIPT_INVALID_IMAGE",
				"error" to "The receipt image could not be prepared.",
			))
			return
		}
		val (safeName, bytes) = parsed
		val filename = if (safeName.endsWith(".png", ignoreCase = true)) safeName else "$safeName.png"
		try {
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				val resolver = contentResolver
				val values = ContentValues().apply {
					put(MediaStore.Images.Media.DISPLAY_NAME, filename)
					put(MediaStore.Images.Media.MIME_TYPE, "image/png")
					put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/Owllet")
					put(MediaStore.Images.Media.IS_PENDING, 1)
				}
				val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
				if (uri == null) {
					result.success(mapOf(
						"ok" to false,
						"code" to "RECEIPT_SAVE_FAILED",
						"error" to "Could not save the receipt. Check storage access and try again.",
					))
					return
				}
				val stream = resolver.openOutputStream(uri)
				if (stream == null) {
					resolver.delete(uri, null, null)
					result.success(mapOf(
						"ok" to false,
						"code" to "RECEIPT_SAVE_FAILED",
						"error" to "Could not save the receipt. Check storage access and try again.",
					))
					return
				}
				stream.use { it.write(bytes) }
				values.clear()
				values.put(MediaStore.Images.Media.IS_PENDING, 0)
				resolver.update(uri, values, null, null)
				result.success(mapOf("ok" to true, "uri" to uri.toString()))
				return
			}

			val dir = getExternalFilesDir(Environment.DIRECTORY_PICTURES) ?: filesDir
			val owlletDir = File(dir, "Owllet").apply { mkdirs() }
			val file = File(owlletDir, filename)
			file.outputStream().use { it.write(bytes) }
			result.success(mapOf("ok" to true, "path" to file.absolutePath))
		} catch (error: Exception) {
			Log.e(logTag, "Receipt save failed", error)
			result.success(mapOf(
				"ok" to false,
				"code" to "RECEIPT_SAVE_FAILED",
				"error" to "Could not save the receipt. Check storage access and try again.",
			))
		}
	}

	private fun shareReceiptImage(arguments: Any?, result: MethodChannel.Result) {
		val parsed = receiptBytes(arguments)
		if (parsed == null) {
			result.success(mapOf(
				"ok" to false,
				"code" to "RECEIPT_INVALID_IMAGE",
				"error" to "The receipt image could not be prepared.",
			))
			return
		}
		val args = arguments as? Map<*, *>
		val text = args?.get("text")?.toString().orEmpty()
		val (safeName, bytes) = parsed
		val filename = if (safeName.endsWith(".png", ignoreCase = true)) safeName else "$safeName.png"
		try {
			val dir = File(cacheDir, "shared_receipts").apply { mkdirs() }
			val file = File(dir, filename)
			file.outputStream().use { it.write(bytes) }
			val uri: Uri = FileProvider.getUriForFile(
				this,
				"${applicationContext.packageName}.flutter_inappwebview_android.fileprovider",
				file,
			)
			val intent = Intent(Intent.ACTION_SEND).apply {
				type = "image/png"
				putExtra(Intent.EXTRA_STREAM, uri)
				// Some Android share targets only inherit temporary URI access
				// from ClipData, even when EXTRA_STREAM and the grant flag exist.
				clipData = ClipData.newRawUri("Owllet receipt", uri)
				if (text.isNotBlank()) {
					putExtra(Intent.EXTRA_TEXT, text)
				}
				addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
			}
			val chooser = Intent.createChooser(intent, "Share receipt").apply {
				addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
			}
			startActivity(chooser)
			result.success(mapOf("ok" to true))
		} catch (error: Exception) {
			Log.e(logTag, "Receipt share failed", error)
			result.success(mapOf(
				"ok" to false,
				"code" to "RECEIPT_SHARE_FAILED",
				"error" to "Could not open sharing. Try again or save the receipt first.",
			))
		}
	}
}
