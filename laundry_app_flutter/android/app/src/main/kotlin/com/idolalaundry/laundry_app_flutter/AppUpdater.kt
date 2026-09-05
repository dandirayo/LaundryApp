package com.idolalaundry.laundry_app_flutter

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicBoolean

/** Only invoked by the Update button. Android always confirms installation. */
@Suppress("DEPRECATION")
class AppUpdater(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "idola/app_updates")
    private val busy = AtomicBoolean(false)
    private val pm get() = activity.packageManager
    private fun installed() = pm.getPackageInfo(activity.packageName, PackageManager.GET_SIGNATURES)
    private fun version(info: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "info" -> {
                    val info = installed()
                    result.success(mapOf("build" to version(info), "version" to info.versionName,
                        "package" to activity.packageName, "abis" to Build.SUPPORTED_ABIS.toList()))
                }
                "install" -> {
                    if (busy.get()) {
                        result.error("busy", "Unduhan masih berjalan.", null)
                    } else if (Build.VERSION.SDK_INT >= 26 && !pm.canRequestPackageInstalls()) {
                        try {
                            activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:${activity.packageName}")))
                            result.success("permission_required")
                        } catch (e: Exception) {
                            result.error("permission", "Buka pengaturan HP dan izinkan Idola One memasang pembaruan.", null)
                        }
                    } else {
                        val url = call.argument<String>("url") ?: ""
                        val hash = call.argument<String>("sha256") ?: ""
                        val size = call.argument<Number>("size")?.toLong() ?: 0
                        val build = call.argument<Number>("build")?.toLong() ?: 0
                        downloadAndInstall(url, hash, size, build, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun downloadAndInstall(url: String, hash: String, size: Long, build: Long,
                                   result: MethodChannel.Result) {
        if (!busy.compareAndSet(false, true)) return
        Thread {
            val folder = File(activity.cacheDir, "updates").apply { mkdirs() }
            val partial = File(folder, "download.part")
            val apk = File(folder, "update.apk")
            try {
                val address = URL(url)
                require(address.protocol == "https" && address.host == "sqydcdhvsmmkvlpsjzgx.supabase.co"
                    && (address.port == -1 || address.port == 443) && address.userInfo == null
                    && address.path.startsWith("/storage/v1/object/public/app-releases/android/"))
                require(hash.matches(Regex("[a-fA-F0-9]{64}")) && size in 1..100_000_000)
                require(build > version(installed()))
                if (!apk.exists() || apk.length() != size || digest(apk) != hash.lowercase()) {
                    val connection = address.openConnection() as HttpURLConnection
                    connection.connectTimeout = 20000
                    connection.readTimeout = 30000
                    connection.instanceFollowRedirects = false
                    try {
                        check(connection.responseCode == 200)
                        var received = 0L
                        var lastPercent = -1
                        connection.inputStream.use { input ->
                            partial.outputStream().use { output ->
                                val buffer = ByteArray(65536)
                                while (true) {
                                    val count = input.read(buffer)
                                    if (count < 0) break
                                    received += count
                                    check(received <= size)
                                    output.write(buffer, 0, count)
                                    val percent = (received * 100 / size).toInt()
                                    if (percent != lastPercent) {
                                        lastPercent = percent
                                        activity.runOnUiThread { channel.invokeMethod("progress", percent) }
                                    }
                                }
                            }
                        }
                        check(received == size && digest(partial) == hash.lowercase())
                        if (apk.exists()) check(apk.delete())
                        check(partial.renameTo(apk))
                    } finally { connection.disconnect() }
                }
                val candidate = pm.getPackageArchiveInfo(apk.path, PackageManager.GET_SIGNATURES)
                    ?: error("Invalid APK")
                check(candidate.packageName == activity.packageName && version(candidate) == build)
                val oldSigners = installed().signatures?.map { it.toCharsString() }?.toSet()
                val newSigners = candidate.signatures?.map { it.toCharsString() }?.toSet()
                check(!oldSigners.isNullOrEmpty() && oldSigners == newSigners)
                activity.runOnUiThread {
                    try {
                        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", apk)
                        activity.startActivity(Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        })
                        result.success("installer_opened")
                    } catch (e: Exception) {
                        result.error("install", "Pemasang Android tidak dapat dibuka. Coba Update lagi.", null)
                    } finally { busy.set(false) }
                }
            } catch (e: Exception) {
                partial.delete()
                activity.runOnUiThread {
                    busy.set(false)
                    result.error("download", "Update belum berhasil diunduh atau diverifikasi. Periksa koneksi dan coba lagi.", null)
                }
            }
        }.start()
    }

    private fun digest(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(65536)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
}
