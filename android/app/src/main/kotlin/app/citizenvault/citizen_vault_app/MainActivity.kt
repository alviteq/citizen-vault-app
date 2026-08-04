package app.citizenvault.citizen_vault_app

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import android.os.StatFs
import android.util.Log
import android.view.WindowManager
import androidx.exifinterface.media.ExifInterface
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private var pendingExport: PendingExport? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "exportArchive" -> exportArchive(
                        call.argument<String>("sourcePath"),
                        result,
                    )
                    "exportDocument" -> exportDocument(
                        call.argument<String>("sourcePath"),
                        call.argument<String>("suggestedName"),
                        call.argument<String>("mimeType"),
                        result,
                    )
                    "availableBytes" -> availableBytes(
                        call.argument<String>("path"),
                        result,
                    )
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OCR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "recognizeText" -> recognizeText(
                        call.argument<String>("path"),
                        call.argument<String>("language"),
                        result,
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private fun recognizeText(
        path: String?,
        language: String?,
        result: MethodChannel.Result,
    ) {
        val source = validatedPrivateFile(path)
        if (source == null || source.length() <= 0L) {
            result.error("INVALID_SOURCE", "OCR source is unavailable", null)
            return
        }
        val decoded = try {
            decodeOcrImage(source)
        } catch (error: Throwable) {
            Log.e(LOG_TAG, "OCR source decode failed", error)
            result.error("INVALID_SOURCE", "OCR source is unsupported", null)
            return
        }
        if (decoded == null) {
            result.error("INVALID_SOURCE", "OCR source is unsupported", null)
            return
        }
        val (image, bitmap) = decoded
        val recognizer = when (language) {
            "hi", "mr" -> TextRecognition.getClient(
                DevanagariTextRecognizerOptions.Builder().build(),
            )
            else -> TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        }
        recognizer.process(image)
            .addOnSuccessListener { text ->
                recognizer.close()
                bitmap.recycle()
                result.success(text.text)
            }
            .addOnFailureListener { error ->
                recognizer.close()
                bitmap.recycle()
                Log.e(LOG_TAG, "ML Kit text recognition failed", error)
                result.error(
                    "OCR_RETRYABLE",
                    "Text recognition temporarily failed",
                    null,
                )
            }
    }

    private fun decodeOcrImage(source: File): Pair<InputImage, Bitmap>? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(source.path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        var sampleSize = 1
        while (
            bounds.outWidth / sampleSize > OCR_LONGEST_EDGE ||
            bounds.outHeight / sampleSize > OCR_LONGEST_EDGE
        ) {
            sampleSize *= 2
        }
        val bitmap = BitmapFactory.decodeFile(
            source.path,
            BitmapFactory.Options().apply {
                inSampleSize = sampleSize
                inPreferredConfig = Bitmap.Config.ARGB_8888
            },
        ) ?: return null
        val rotation = try {
            ExifInterface(source).rotationDegrees
        } catch (_: Throwable) {
            0
        }
        return InputImage.fromBitmap(bitmap, rotation) to bitmap
    }

    private fun exportArchive(sourcePath: String?, result: MethodChannel.Result) {
        val source = validatedPrivateFile(sourcePath)
        if (source == null || !source.name.endsWith(".cvault") || source.length() <= 0L) {
            result.error("INVALID_SOURCE", "Backup source is unavailable", null)
            return
        }
        startExport(source, source.name, "application/octet-stream", result)
    }

    private fun exportDocument(
        sourcePath: String?,
        suggestedName: String?,
        mimeType: String?,
        result: MethodChannel.Result,
    ) {
        val source = validatedPrivateFile(sourcePath)
        if (
            source == null ||
            source.length() <= 0L ||
            !isSafeSuggestedName(suggestedName) ||
            mimeType !in ALLOWED_DOCUMENT_MIME_TYPES
        ) {
            result.error("INVALID_SOURCE", "Document source is unavailable", null)
            return
        }
        startExport(source, suggestedName!!, mimeType!!, result)
    }

    private fun startExport(
        source: File,
        suggestedName: String,
        mimeType: String,
        result: MethodChannel.Result,
    ) {
        if (pendingExport != null) {
            result.error("EXPORT_BUSY", "Another export is active", null)
            return
        }
        pendingExport = PendingExport(source, result)
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, suggestedName)
        }
        try {
            startActivityForResult(intent, EXPORT_REQUEST_CODE)
        } catch (error: Throwable) {
            pendingExport = null
            result.error("EXPORT_UNAVAILABLE", "Document provider unavailable", null)
        }
    }

    @Deprecated("Uses the stable activity-result bridge required by FlutterFragmentActivity.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != EXPORT_REQUEST_CODE) return
        val pending = pendingExport ?: return
        pendingExport = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pending.result.success(false)
            return
        }
        val destination = data.data!!
        Thread {
            try {
                contentResolver.openOutputStream(destination, "w").use { output ->
                    requireNotNull(output)
                    pending.source.inputStream().use { input ->
                        input.copyTo(output, DEFAULT_BUFFER_SIZE)
                        output.flush()
                    }
                }
                runOnUiThread { pending.result.success(true) }
            } catch (error: Throwable) {
                runOnUiThread {
                    pending.result.error(
                        "EXPORT_FAILED",
                        "Encrypted backup could not be exported",
                        null,
                    )
                }
            }
        }.start()
    }

    private fun availableBytes(path: String?, result: MethodChannel.Result) {
        val directory = validatedPrivateDirectory(path)
        if (directory == null) {
            result.error("INVALID_PATH", "Storage path is unavailable", null)
            return
        }
        try {
            result.success(StatFs(directory.path).availableBytes)
        } catch (error: Throwable) {
            result.error("STORAGE_UNAVAILABLE", "Storage capacity unavailable", null)
        }
    }

    private fun validatedPrivateFile(path: String?): File? {
        if (path == null) return null
        return try {
            val file = File(path).canonicalFile
            if (isInsidePrivateStorage(file) && file.isFile) file else null
        } catch (error: Throwable) {
            null
        }
    }

    private fun validatedPrivateDirectory(path: String?): File? {
        if (path == null) return null
        return try {
            val directory = File(path).canonicalFile
            if (isInsidePrivateStorage(directory) && directory.isDirectory) directory else null
        } catch (error: Throwable) {
            null
        }
    }

    private fun isInsidePrivateStorage(file: File): Boolean {
        val roots = listOf(filesDir, cacheDir, noBackupFilesDir).map { it.canonicalFile }
        return roots.any { root -> file.path == root.path || file.path.startsWith("${root.path}/") }
    }

    private fun isSafeSuggestedName(name: String?): Boolean =
        name != null &&
            name.length in 1..255 &&
            name != "." &&
            name != ".." &&
            !name.contains('/') &&
            !name.contains('\\') &&
            !name.contains('\u0000')

    private data class PendingExport(
        val source: File,
        val result: MethodChannel.Result,
    )

    private companion object {
        const val FILE_CHANNEL = "citizen_vault/files"
        const val OCR_CHANNEL = "app.citizenvault/ocr"
        const val LOG_TAG = "OwnKeepOCR"
        const val OCR_LONGEST_EDGE = 2400
        const val EXPORT_REQUEST_CODE = 47_011
        val ALLOWED_DOCUMENT_MIME_TYPES = setOf(
            "application/pdf",
            "image/jpeg",
            "image/png",
            "image/webp",
            "image/gif",
            "image/bmp",
            "image/tiff",
            "image/heic",
            "image/heif",
            "text/plain",
            "text/csv",
            "application/msword",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "application/vnd.ms-excel",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "application/vnd.ms-powerpoint",
            "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        )
    }
}
