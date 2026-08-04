package ch.snappar.android

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import androidx.core.content.FileProvider
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import java.io.File
import java.io.FileOutputStream

class GodotAndroidPlugin(godot: Godot) : GodotPlugin(godot) {
    companion object {
        private const val REQUEST_CAMERA = 4101
        private const val REQUEST_GALLERY = 4102
        private const val SIGNAL_IMAGE_SELECTED = "image_selected"
        private const val SIGNAL_MEDIA_ERROR = "media_error"
        private const val FILE_PROVIDER_AUTHORITY = "ch.snappar.game.snappar.files"
    }

    private var pendingPhotoFile: File? = null

    override fun getPluginName(): String = BuildConfig.GODOT_PLUGIN_NAME

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo(SIGNAL_IMAGE_SELECTED, String::class.java),
        SignalInfo(SIGNAL_MEDIA_ERROR, String::class.java),
    )

    @UsedByGodot
    fun takePhoto() {
        runOnHostThread {
            val host = activity ?: return@runOnHostThread emitError("Kamera ist nicht verfuegbar")
            try {
                val output = File.createTempFile("snap-par-camera-", ".jpg", host.cacheDir)
                val uri = fileUri(host, output)
                val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                    putExtra(MediaStore.EXTRA_OUTPUT, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                }
                if (intent.resolveActivity(host.packageManager) == null) {
                    output.delete()
                    emitError("Keine Kamera-App gefunden")
                    return@runOnHostThread
                }
                pendingPhotoFile = output
                host.startActivityForResult(intent, REQUEST_CAMERA)
            } catch (exception: Exception) {
                emitError("Foto konnte nicht gestartet werden")
            }
        }
    }

    @UsedByGodot
    fun pickImage() {
        runOnHostThread {
            val host = activity ?: return@runOnHostThread emitError("Galerie ist nicht verfuegbar")
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "image/*"
            }
            if (intent.resolveActivity(host.packageManager) == null) {
                emitError("Keine Galerie-App gefunden")
                return@runOnHostThread
            }
            host.startActivityForResult(intent, REQUEST_GALLERY)
        }
    }

    @UsedByGodot
    fun shareImage(path: String) {
        runOnHostThread {
            val host = activity ?: return@runOnHostThread emitError("Teilen ist nicht verfuegbar")
            val file = File(path)
            if (!file.isFile) {
                emitError("Das Bild zum Teilen fehlt")
                return@runOnHostThread
            }
            try {
                val uri = fileUri(host, file)
                val share = Intent(Intent.ACTION_SEND).apply {
                    type = "image/png"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                host.startActivity(Intent.createChooser(share, "Snap Par Bild teilen"))
            } catch (exception: Exception) {
                emitError("Das Bild konnte nicht geteilt werden")
            }
        }
    }

    override fun onMainActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onMainActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            REQUEST_CAMERA -> handleCameraResult(resultCode)
            REQUEST_GALLERY -> handleGalleryResult(resultCode, data?.data)
        }
    }

    private fun handleCameraResult(resultCode: Int) {
        val output = pendingPhotoFile
        pendingPhotoFile = null
        if (resultCode != Activity.RESULT_OK || output == null || output.length() == 0L) {
            output?.delete()
            if (resultCode != Activity.RESULT_CANCELED) {
                emitError("Foto konnte nicht gespeichert werden")
            }
            return
        }
        emitImage(output.absolutePath)
    }

    private fun handleGalleryResult(resultCode: Int, source: Uri?) {
        if (resultCode != Activity.RESULT_OK || source == null) {
            if (resultCode != Activity.RESULT_CANCELED) {
                emitError("Bild konnte nicht geoeffnet werden")
            }
            return
        }
        val host = activity ?: return emitError("Galerie ist nicht verfuegbar")
        try {
            val suffix = when (host.contentResolver.getType(source)) {
                "image/png" -> ".png"
                "image/webp" -> ".webp"
                else -> ".jpg"
            }
            val output = File.createTempFile("snap-par-gallery-", suffix, host.cacheDir)
            host.contentResolver.openInputStream(source).use { input ->
                if (input == null) throw IllegalStateException("No input stream")
                FileOutputStream(output).use { target -> input.copyTo(target) }
            }
            emitImage(output.absolutePath)
        } catch (exception: Exception) {
            emitError("Bild konnte nicht importiert werden")
        }
    }

    private fun fileUri(host: Activity, file: File): Uri =
        FileProvider.getUriForFile(host, FILE_PROVIDER_AUTHORITY, file)

    private fun emitImage(path: String) {
        runOnRenderThread { emitSignal(SIGNAL_IMAGE_SELECTED, path) }
    }

    private fun emitError(message: String) {
        runOnRenderThread { emitSignal(SIGNAL_MEDIA_ERROR, message) }
    }
}
