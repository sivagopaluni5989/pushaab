package com.bravesstudio.wastatusfastsaver

import android.content.ContentResolver
import android.net.Uri
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class MainActivity: FlutterActivity() {
  private val CHANNEL = "com.bravesstudio.wastatusfastsaver/content_reader"

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
      when (call.method) {
        "readContentUriToFile" -> {
          val uriString = call.argument<String>("uri")
          if (uriString == null) {
            result.error("INVALID_ARGS", "uri is null", null)
            return@setMethodCallHandler
          }
          try {
            val tempPath = copyContentUriToTempFile(uriString)
            if (tempPath != null) result.success(tempPath) else result.error("READ_FAILED", "Failed to read URI", null)
          } catch (e: Exception) {
            result.error("EXCEPTION", e.message, null)
          }
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun copyContentUriToTempFile(uriString: String): String? {
    val resolver: ContentResolver = applicationContext.contentResolver
    val uri = Uri.parse(uriString)
    val input: InputStream? = resolver.openInputStream(uri) ?: return null

    val cacheDir = applicationContext.cacheDir
    val outFile = File.createTempFile("status_", null, cacheDir)

    // Safely use the nullable InputStream and close resources automatically
    input.use { inp ->
      if (inp == null) return null
      FileOutputStream(outFile).use { out ->
        val buffer = ByteArray(8 * 1024)
        var read: Int
        while (inp.read(buffer).also { read = it } != -1) {
          out.write(buffer, 0, read)
        }
        out.flush()
      }
    }

    return outFile.absolutePath
  }
}
