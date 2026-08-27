package com.dynops.bcwms.feature

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import com.dynops.bcwms.BuildConfig
import com.dynops.bcwms.ui.WmsActionLabel
import com.dynops.bcwms.ui.WmsGlyph
import com.dynops.bcwms.ui.bcwmsStatus
import com.dynops.bcwms.ui.operatorFacingStatus
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * In-app update channel for the sideload (APK fallback) distribution. The
 * Play Store path is handled by Play's own auto-update; this module fires
 * only when the running app was installed outside of Play (UNKNOWN_SOURCES).
 *
 * Boot:
 *   GET BuildConfig.UPDATE_MANIFEST_URL
 *   { versionCode, versionName, apkUrl, sha256, releaseNotes }
 * Compare versionCode > BuildConfig.VERSION_CODE → show dialog → download
 * via DownloadManager → SHA-256 verify → ACTION_INSTALL_PACKAGE.
 */

private const val PREFS = "bcwms_prefs"
private const val KEY_UPDATE_CHECK = "bcwms.updates.enabled"
private const val KEY_LAST_PROMPTED = "bcwms.updates.lastPromptedVersionCode"
private const val KEY_LAST_CHECKED_AT = "bcwms.updates.lastCheckedAt"
private const val UPDATE_POLL_INTERVAL_MS = 4L * 60L * 60L * 1_000L

private val UPDATE_MANIFEST_URL = BuildConfig.UPDATE_MANIFEST_URL

data class UpdateManifest(
    val versionCode: Int,
    val versionName: String,
    val apkUrl: String,
    val sha256: String,
    val releaseNotes: String,
)

private val SHA256_HEX = Regex("^[0-9a-fA-F]{64}$")
private val ALLOWED_APK_HOSTS = setOf(
    "app.bcwms.dynops.com",
    "icy-glacier-067645703.7.azurestaticapps.net",
    "github.com",
    "objects.githubusercontent.com",
    "release-assets.githubusercontent.com",
)

fun isUpdateCheckEnabled(context: Context): Boolean =
    context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_UPDATE_CHECK, true)

fun setUpdateCheckEnabled(context: Context, enabled: Boolean) {
    context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        .putBoolean(KEY_UPDATE_CHECK, enabled).apply()
}

private fun lastCheckedAt(context: Context): Long =
    context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(KEY_LAST_CHECKED_AT, 0L)

private fun saveLastCheckedAt(context: Context, value: Long = System.currentTimeMillis()) {
    context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        .putLong(KEY_LAST_CHECKED_AT, value).apply()
}

private fun installedAt(context: Context): Long = runCatching {
    @Suppress("DEPRECATION")
    context.packageManager.getPackageInfo(context.packageName, 0).lastUpdateTime
}.getOrDefault(0L)

private fun formatUpdateDate(value: Long): String = if (value <= 0L) {
    "Henüz kontrol edilmedi"
} else {
    SimpleDateFormat("dd.MM.yyyy HH:mm", Locale("tr", "TR")).format(Date(value))
}

/**
 * Top-level composable that polls once on first composition. Should be
 * placed near AppRoot so the dialog is reachable from any screen.
 */
@Composable
fun UpdateChecker() {
    val context = LocalContext.current
    var manifest by remember { mutableStateOf<UpdateManifest?>(null) }

    LaunchedEffect(Unit) {
        if (!isUpdateCheckEnabled(context)) return@LaunchedEffect
        while (true) {
            if (manifest == null) {
                try {
                    val fetched = withContext(Dispatchers.IO) { fetchManifest() }
                    if (fetched != null) saveLastCheckedAt(context)
                    val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    val last = prefs.getInt(KEY_LAST_PROMPTED, 0)
                    if (fetched != null && fetched.versionCode > BuildConfig.VERSION_CODE && fetched.versionCode != last) {
                        manifest = fetched
                    }
                } catch (_: Throwable) {
                    // Ağ yoksa saha operasyonunu kesme; dört saat sonra yeniden dene.
                }
            }
            delay(UPDATE_POLL_INTERVAL_MS)
        }
    }

    val m = manifest ?: return
    UpdatePromptDialog(
        manifest = m,
        onClose = {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putInt(KEY_LAST_PROMPTED, m.versionCode).apply()
            manifest = null
        },
    )
}

/** Bağlantı ekranından operatörün istediği anda sürüm kontrolü yapabilmesi için. */
@Composable
fun AppUpdateCard() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val statusColors = bcwmsStatus()
    var checking by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf("") }
    var messageIsError by remember { mutableStateOf(false) }
    var latestVersion by remember { mutableStateOf<String?>(null) }
    var lastCheck by remember { mutableLongStateOf(lastCheckedAt(context)) }
    var availableUpdate by remember { mutableStateOf<UpdateManifest?>(null) }
    val installDate = remember { installedAt(context) }

    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.large,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.55f)),
    ) {
        Column(Modifier.fillMaxWidth().padding(16.dp)) {
            Text("Sürüm ve Güncelleme", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
            Text(
                "✓ Uzaktan güncelleme etkin",
                style = MaterialTheme.typography.bodySmall,
                color = statusColors.success,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                "⚡ Hızlı indirme etkin",
                style = MaterialTheme.typography.bodySmall,
                color = statusColors.success,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                "✓ ${BuildConfig.VERSION_NAME} sürümü kurulu",
                style = MaterialTheme.typography.bodySmall,
                color = statusColors.success,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.height(10.dp))
            Text("Mevcut sürüm: v${BuildConfig.VERSION_NAME}", style = MaterialTheme.typography.bodyMedium)
            Text("Son güncelleme: ${formatUpdateDate(installDate)}", style = MaterialTheme.typography.bodySmall)
            Text("Son kontrol: ${formatUpdateDate(lastCheck)}", style = MaterialTheme.typography.bodySmall)
            latestVersion?.let {
                Text("Sunucudaki sürüm: v$it", style = MaterialTheme.typography.bodySmall)
            }
            if (message.isNotBlank()) {
                Spacer(Modifier.height(8.dp))
                Text(
                    message,
                    color = if (messageIsError) statusColors.danger else statusColors.success,
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.SemiBold,
                )
            }
            Spacer(Modifier.height(12.dp))
            Button(
                enabled = !checking,
                onClick = {
                    scope.launch {
                        checking = true
                        message = "Güncelleme sunucusu kontrol ediliyor…"
                        messageIsError = false
                        val fetched = withContext(Dispatchers.IO) {
                            runCatching { fetchManifest() }.getOrNull()
                        }
                        checking = false
                        if (fetched == null) {
                            message = "Güncelleme hizmetine ulaşılamadı. İnternet açıksa son sürüm henüz sunucuya yayımlanmamış olabilir."
                            messageIsError = true
                        } else {
                            val checkedAt = System.currentTimeMillis()
                            saveLastCheckedAt(context, checkedAt)
                            lastCheck = checkedAt
                            latestVersion = fetched.versionName
                            if (fetched.versionCode > BuildConfig.VERSION_CODE) {
                                message = "Yeni sürüm bulundu: v${fetched.versionName}"
                                availableUpdate = fetched
                            } else {
                                message = "Uygulama güncel."
                            }
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth().height(50.dp),
            ) {
                if (checking) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(19.dp),
                        strokeWidth = 2.dp,
                        color = MaterialTheme.colorScheme.onPrimary,
                    )
                    Spacer(Modifier.width(8.dp))
                    Text("Kontrol ediliyor…")
                } else {
                    WmsActionLabel(WmsGlyph.REFRESH, "Güncellemeyi Kontrol Et")
                }
            }
        }
    }

    availableUpdate?.let { update ->
        UpdatePromptDialog(
            manifest = update,
            onClose = { availableUpdate = null },
        )
    }
}

@Composable
private fun UpdatePromptDialog(
    manifest: UpdateManifest,
    onClose: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var downloading by remember(manifest.versionCode) { mutableStateOf(false) }
    var downloadProgress by remember(manifest.versionCode) { mutableStateOf(0) }
    var error by remember(manifest.versionCode) { mutableStateOf<String?>(null) }
    val status = bcwmsStatus()
    AlertDialog(
        onDismissRequest = onClose,
        title = { Text("Yeni sürüm hazır: v${manifest.versionName}") },
        text = {
            Column {
                Text(
                    "Şu anki sürüm: v${BuildConfig.VERSION_NAME}. Güncellemek için 'İndir' butonuna dokunun.",
                    style = MaterialTheme.typography.bodyMedium,
                )
                if (manifest.releaseNotes.isNotBlank()) {
                    Spacer(Modifier.height(8.dp))
                    Text(manifest.releaseNotes, style = MaterialTheme.typography.bodySmall)
                }
                if (downloading) {
                    Spacer(Modifier.height(8.dp))
                    LinearProgressIndicator(progress = { downloadProgress / 100f })
                    Text("%${downloadProgress}", style = MaterialTheme.typography.bodySmall)
                }
                error?.let {
                    Spacer(Modifier.height(8.dp))
                    Text(operatorFacingStatus(it), color = status.danger)
                }
            }
        },
        confirmButton = {
            TextButton(
                enabled = !downloading,
                onClick = {
                    scope.launch {
                        downloading = true
                        error = null
                        try {
                            val apk = withContext(Dispatchers.IO) {
                                downloadApk(context, manifest, onProgress = { downloadProgress = it })
                            }
                            // SHA-256 is mandatory: manifest fetch already validates the hex
                            // form + apkUrl allowlist, but we recheck here in case the manifest
                            // was cached and the on-disk APK was tampered with.
                            if (!verifySha256(apk, manifest.sha256)) {
                                error = "Doğrulama başarısız — paket bozulmuş olabilir."
                                apk.delete()
                            } else {
                                installApk(context, apk)
                                onClose()
                            }
                        } catch (t: Throwable) {
                            error = "HATA: Güncelleme indirilemedi. Bağlantıyı kontrol edip tekrar deneyin."
                        } finally {
                            downloading = false
                        }
                    }
                }
            ) { Text(if (downloading) "İndiriliyor…" else "İndir & yükle") }
        },
        dismissButton = {
            TextButton(onClick = onClose) { Text("Şimdi değil") }
        },
    )
}

private fun fetchManifest(): UpdateManifest? {
    val manifestUrl = URL(UPDATE_MANIFEST_URL)
    require(manifestUrl.protocol == "https") { "manifest must be served over HTTPS" }
    val conn = (manifestUrl.openConnection() as HttpURLConnection).apply {
        connectTimeout = 8_000
        readTimeout = 15_000
        requestMethod = "GET"
        setRequestProperty("Accept", "application/json")
    }
    return try {
        if (conn.responseCode / 100 != 2) return null
        val body = conn.inputStream.bufferedReader().use { it.readText() }
        val obj = org.json.JSONObject(body)
        val sha = obj.optString("sha256").trim()
        require(SHA256_HEX.matches(sha)) { "manifest sha256 missing or malformed" }
        require(obj.optInt("versionCode") > 0) { "manifest versionCode missing or malformed" }
        require(obj.optString("versionName").isNotBlank()) { "manifest versionName missing" }
        val apkUrlRaw = obj.optString("apkUrl")
        val apkUri = Uri.parse(apkUrlRaw)
        require(apkUri.scheme == "https") { "apkUrl must be https" }
        val host = apkUri.host?.lowercase().orEmpty()
        require(host in ALLOWED_APK_HOSTS) { "apkUrl host not on allowlist: $host" }
        UpdateManifest(
            versionCode = obj.optInt("versionCode"),
            versionName = obj.optString("versionName"),
            apkUrl = apkUrlRaw,
            sha256 = sha,
            releaseNotes = obj.optString("releaseNotes"),
        )
    } catch (e: IllegalArgumentException) {
        android.util.Log.w("BcwmsUpdate", "rejecting manifest: ${e.message}")
        null
    } finally {
        conn.disconnect()
    }
}

private suspend fun downloadApk(
    context: Context,
    manifest: UpdateManifest,
    onProgress: suspend (Int) -> Unit,
): File {
    val dest = File(
        context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS),
        "bcwms-${manifest.versionCode}.apk",
    ).apply {
        if (exists()) delete()
    }

    val dm = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    val request = DownloadManager.Request(Uri.parse(manifest.apkUrl))
        .setTitle("BCWMS v${manifest.versionName}")
        .setDestinationInExternalFilesDir(context, Environment.DIRECTORY_DOWNLOADS, "bcwms-${manifest.versionCode}.apk")
        .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
        .setMimeType("application/vnd.android.package-archive")
    val id = dm.enqueue(request)

    var finishedFile: File? = null
    while (finishedFile == null) {
        val query = DownloadManager.Query().setFilterById(id)
        dm.query(query).use { cursor ->
            if (cursor != null && cursor.moveToFirst()) {
                val downloaded = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
                val total = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
                if (total > 0) onProgress(((downloaded * 100) / total).toInt())
                val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
                when (status) {
                    DownloadManager.STATUS_SUCCESSFUL -> {
                        // DownloadManager zaten nihai, FileProvider tarafından
                        // paylaşılabilen hedefe yazdı. 30 MB dosyayı cache'e bir
                        // kez daha kopyalamak özellikle eski terminallerde
                        // kurulum ekranını gereksiz yere geciktiriyordu.
                        if (!dest.isFile || dest.length() <= 0L)
                            error("downloaded APK missing")
                        finishedFile = dest
                    }
                    DownloadManager.STATUS_FAILED -> {
                        val reason = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
                        error("Download failed (reason $reason)")
                    }
                }
            }
        }
        if (finishedFile == null) delay(700)
    }
    onProgress(100)
    return finishedFile!!
}

private fun verifySha256(file: File, expected: String): Boolean {
    val digest = MessageDigest.getInstance("SHA-256")
    file.inputStream().use { input ->
        val buffer = ByteArray(8 * 1024)
        while (true) {
            val read = input.read(buffer)
            if (read <= 0) break
            digest.update(buffer, 0, read)
        }
    }
    val computed = digest.digest().joinToString("") { "%02x".format(it) }
    return computed.equals(expected.trim(), ignoreCase = true)
}

private fun installApk(context: Context, apk: File) {
    val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", apk)
    val intent = Intent(Intent.ACTION_VIEW).apply {
        setDataAndType(uri, "application/vnd.android.package-archive")
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    context.startActivity(intent)
}

/** Optional registry for when the app is foregrounded later — keeps surface
 *  small until needed. */
@Suppress("unused")
class UpdateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        // currently a no-op; reserved for completed-download notification.
    }
}
