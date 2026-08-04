package ch.snappar.android

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
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
        private const val REQUEST_GALLERY_PERMISSION = 4103
        private const val SIGNAL_IMAGE_SELECTED = "image_selected"
        private const val SIGNAL_MEDIA_ERROR = "media_error"
        private const val FILE_PROVIDER_AUTHORITY = "ch.snappar.game.snappar.files"
    }

    private var pendingPhotoFile: File? = null
    private var galleryPendingAfterPermission = false

    override fun getPluginName(): String = BuildConfig.GODOT_PLUGIN_NAME

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo(SIGNAL_IMAGE_SELECTED, String::class.java),
        SignalInfo(SIGNAL_MEDIA_ERROR, String::class.java),
    )

    @UsedByGodot
    fun takePhoto() {
        val host = activity ?: return emitError("Kamera ist nicht verfuegbar")
        host.runOnUiThread {
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
                    return@runOnUiThread
                }
                pendingPhotoFile = output
                host.startActivityForResult(intent, REQUEST_CAMERA)
            } catch (_: Exception) {
                emitError("Foto konnte nicht gestartet werden")
            }
        }
    }

    @UsedByGodot
    fun pickImage() {
        val host = activity ?: return emitError("Galerie ist nicht verfuegbar")
        host.runOnUiThread {
            val permission = galleryPermission()
            if (permission == null || ContextCompat.checkSelfPermission(host, permission) == PackageManager.PERMISSION_GRANTED) {
                launchGalleryPicker(host)
                return@runOnUiThread
            }

            galleryPendingAfterPermission = true
            ActivityCompat.requestPermissions(host, arrayOf(permission), REQUEST_GALLERY_PERMISSION)
        }
    }

    @UsedByGodot
    fun shareImage(path: String) {
        val host = activity ?: return emitError("Teilen ist nicht verfuegbar")
        host.runOnUiThread {
            val file = File(path)
            if (!file.isFile) {
                emitError("Das Bild zum Teilen fehlt")
                return@runOnUiThread
            }
            try {
                val uri = fileUri(host, file)
                val share = Intent(Intent.ACTION_SEND).apply {
                    type = "image/png"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                host.startActivity(Intent.createChooser(share, "Snap Par Bild teilen"))
            } catch (_: Exception) {
                emitError("Das Bild konnte nicht geteilt werden")
            }
        }
    }

    override fun onMainRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onMainRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_GALLERY_PERMISSION || !galleryPendingAfterPermission) return

        galleryPendingAfterPermission = false
        val host = activity ?: return emitError("Galerie ist nicht verfuegbar")
        host.runOnUiThread {
            // The Android system picker remains usable even when broad media access is declined.
            launchGalleryPicker(host)
        }
    }

    override fun onMainActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onMainActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            REQUEST_CAMERA -> handleCameraResult(resultCode)
            REQUEST_GALLERY -> handleGalleryResult(resultCode, data?.data)
        }
    }

    private fun galleryPermission(): String? = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> Manifest.permission.READ_MEDIA_IMAGES
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> Manifest.permission.READ_EXTERNAL_STORAGE
        else -> null
    }

    private fun launchGalleryPicker(host: Activity) {
        val preferredIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Intent(MediaStore.ACTION_PICK_IMAGES).apply { type = "image/*" }
        } else {
            createDocumentPickerIntent()
        }

        val intent = if (preferredIntent.resolveActivity(host.packageManager) != null) {
            preferredIntent
        } else {
            createDocumentPickerIntent()
        }

        if (intent.resolveActivity(host.packageManager) == null) {
            emitError("Kein Bildauswahlprogramm gefunden")
            return
        }
        host.startActivityForResult(intent, REQUEST_GALLERY)
    }

    private fun createDocumentPickerIntent(): Intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
        addCategory(Intent.CATEGORY_OPENABLE)
        type = "image/*"
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
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
            if (output.length() == 0L) throw IllegalStateException("Empty image")
            emitImage(output.absolutePath)
        } catch (_: Exception) {
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
