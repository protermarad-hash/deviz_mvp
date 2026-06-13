package ro.proterm.proventaris

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"devizpro/pdf_exports"
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"savePdfToDownloads" -> {
					val bytes = call.argument<ByteArray>("bytes")
					val fileName = call.argument<String>("fileName").orEmpty().trim()
					val relativeDirectory = call.argument<String>("relativeDirectory")
						.orEmpty()
						.trim()
						.replace('\\', '/')
						.trim('/')

					if (bytes == null || fileName.isEmpty()) {
						result.error(
							"invalid_arguments",
							"Missing bytes or file name for PDF export.",
							null
						)
						return@setMethodCallHandler
					}

					try {
						result.success(
							savePdfToDownloads(
								bytes = bytes,
								fileName = fileName,
								relativeDirectory = relativeDirectory,
							)
						)
					} catch (error: Exception) {
						result.error("save_failed", error.message, null)
					}
				}

				else -> result.notImplemented()
			}
		}
	}

	private fun savePdfToDownloads(
		bytes: ByteArray,
		fileName: String,
		relativeDirectory: String,
	): String {
		val normalizedFileName = if (fileName.lowercase().endsWith(".pdf")) {
			fileName
		} else {
			"$fileName.pdf"
		}
		val downloadsRelativePath = buildString {
			append(Environment.DIRECTORY_DOWNLOADS)
			append('/')
			append("ProVentaris")
			if (relativeDirectory.isNotEmpty()) {
				append('/')
				append(relativeDirectory)
			}
		}

		val resolver = applicationContext.contentResolver
		val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
			MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
		} else {
			MediaStore.Files.getContentUri("external")
		}

		val values = ContentValues().apply {
			put(MediaStore.MediaColumns.DISPLAY_NAME, normalizedFileName)
			put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
			put(MediaStore.MediaColumns.RELATIVE_PATH, downloadsRelativePath)
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				put(MediaStore.MediaColumns.IS_PENDING, 1)
			}
		}

		val uri = resolver.insert(collection, values)
			?: throw IllegalStateException("Nu am putut crea fișierul PDF în Downloads.")

		try {
			resolver.openOutputStream(uri)?.use { stream ->
				stream.write(bytes)
				stream.flush()
			} ?: throw IllegalStateException("Nu am putut deschide fluxul pentru PDF.")

			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				values.clear()
				values.put(MediaStore.MediaColumns.IS_PENDING, 0)
				resolver.update(uri, values, null, null)
			}
		} catch (error: Exception) {
			resolver.delete(uri, null, null)
			throw error
		}

		return "/storage/emulated/0/$downloadsRelativePath/$normalizedFileName"
	}
}
