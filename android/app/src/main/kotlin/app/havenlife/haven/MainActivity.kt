package app.havenlife.haven

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.havenlife.haven/updates")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "version" -> {
                            val current = packageManager.getPackageInfo(packageName, 0)
                            result.success(mapOf(
                                "version" to (current.versionName ?: ""),
                                "build_number" to versionCode(current).toString()
                            ))
                        }
                        "install" -> {
                            val filename = call.argument<String>("filename")
                            val build = call.argument<Int>("build")
                            require(build != null && build > 0 && filename == "haven-$build.apk") {
                                "The update file name is invalid."
                            }
                            result.success(openInstaller(filename!!, build))
                        }
                        else -> result.notImplemented()
                    }
                } catch (failure: IllegalArgumentException) {
                    result.error("update_invalid", failure.message, null)
                } catch (failure: Exception) {
                    result.error("update_unavailable", "Android could not open the update installer.", null)
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun openInstaller(filename: String, build: Int): Boolean {
        val updates = File(cacheDir, "haven-updates").canonicalFile
        val apk = File(updates, filename).canonicalFile
        require(apk.isFile && apk.parentFile == updates) { "The downloaded update is missing." }
        val flags = if (Build.VERSION.SDK_INT >= 28) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }
        val update = packageManager.getPackageArchiveInfo(apk.path, flags)
        val installed = packageManager.getPackageInfo(packageName, flags)
        require(update != null && update.packageName == packageName &&
            versionCode(update) == build.toLong() && versionCode(update) > versionCode(installed)) {
            "This file is not a newer Haven build."
        }
        val trustedSigners = signers(installed)
        require(trustedSigners.isNotEmpty() && signers(update) == trustedSigners) {
            "This update was signed with a different key than this Haven installation."
        }

        if (Build.VERSION.SDK_INT >= 26 && !packageManager.canRequestPackageInstalls()) {
            startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
            return false
        }
        val uri = FileProvider.getUriForFile(this, "$packageName.update-files", apk)
        startActivity(Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        })
        return true
    }

    @Suppress("DEPRECATION")
    private fun signers(info: PackageInfo) =
        (if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners else info.signatures)
            ?.toSet().orEmpty()

    @Suppress("DEPRECATION")
    private fun versionCode(info: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
}
