package com.dynops.bcwms.feature

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.draw.clip
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dynops.bcwms.BcApi
import com.dynops.bcwms.BuildConfig
import com.dynops.bcwms.DeviceAuth
import com.dynops.bcwms.shouldForceProductionFlow
import com.dynops.bcwms.ui.CompanyLogo
import com.dynops.bcwms.ui.StatusText
import com.dynops.bcwms.ui.operatorFacingStatus
import com.dynops.bcwms.ui.resolveCompanyBrand
import kotlinx.coroutines.launch
import org.json.JSONObject

private enum class Step { Email, DeviceCode, SelectEnvCompany, LocalUser, SelectCompanyAfterLogin }

/** Girişte listelenecek kayıtlı WMS operatörü. */
data class LocalUserOption(val username: String, val displayName: String)

/**
 * Kurulum ve saha testi sırasında BC servis hesabıyla yönetici geçişi gerekir.
 * Tüm uygulama flavor'larında kart görünür; operatör girişleri yine Local WMS
 * Users üzerinden yapılmaya devam eder.
 */
internal fun allowAdminBypass(flavor: String): Boolean = true

/**
 * Email-based sign-in: email → device-code (browser) → environment + company selection → connect.
 * No token paste required. Token-paste remains available as an "advanced" fallback.
 */
@Composable
fun LoginFlow(onConnected: (Boolean) -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    // Paylaşımlı BC lisansı modeli: BC servis hesabı + ortam zaten bağlıysa
    // ekran doğrudan WMS operatör girişinden başlar (vardiya/kullanıcı değişimi
    // de "Bağlı" rozetine dokunup buradan yapılır).
    var step by remember { mutableStateOf(if (BcApi.hasToken(context)) Step.LocalUser else Step.Email) }
    var email by remember {
        mutableStateOf(BcApi.getLoginEmail(context, BuildConfig.LOGIN_DEFAULT_EMAIL))
    }
    var editEmail by remember { mutableStateOf(email.isBlank()) }
    var password by remember { mutableStateOf("") }
    var localUsername by remember { mutableStateOf("") }
    var localPassword by remember { mutableStateOf("") }
    var status by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var showAdvanced by remember { mutableStateOf(false) }

    // Kayıtlı WMS operatörleri (BC localUsers) — girişte listeden seçilir.
    var localUsers by remember { mutableStateOf<List<LocalUserOption>>(emptyList()) }
    var usersLoading by remember { mutableStateOf(false) }
    var usersError by remember { mutableStateOf("") }
    var manualUserEntry by remember { mutableStateOf(false) }
    var showPassword by remember { mutableStateOf(false) }
    var showForgotPassword by remember { mutableStateOf(false) }
    // Giriş sonrası şirket seçimi (operatör birden çok şirkete erişebiliyorsa).
    var loginCompanies by remember { mutableStateOf<List<BcApi.Company>>(emptyList()) }
    var companyDiscovering by remember { mutableStateOf(false) }
    var signedInAs by remember { mutableStateOf("") }

    var deviceCode by remember { mutableStateOf<DeviceAuth.DeviceCode?>(null) }
    var envList by remember { mutableStateOf<List<BcApi.EnvCompanies>>(emptyList()) }
    var selectedEnv by remember { mutableStateOf<BcApi.EnvCompanies?>(null) }
    var manualEnv by remember { mutableStateOf("") }
    var lastToken by remember { mutableStateOf("") }

    fun startVerifiedAdminSession() {
        if (busy) return
        scope.launch {
            busy = true
            status = "BC bağlantısı doğrulanıyor..."
            val result = BcApi.testConnection(context)
            busy = false
            if (result.ok) {
                BcApi.startAdminTestSession(context)
                status = "Yönetici olarak bağlandı."
                onConnected(true)
            } else {
                status = "🔴 ${BcApi.connectionFailureMessage(result)}"
                onConnected(false)
            }
        }
    }

    /**
     * Direct username/password sign-in via AAD ROPC. Bypasses browser; works for cloud-only
     * accounts without MFA / Conditional Access blocks. On success: flows into the same
     * env+company selector as the browser path.
     */
    fun startPasswordSignIn() {
        scope.launch {
            busy = true; status = "BC'ye bağlanılıyor..."
            when (val t = DeviceAuth.loginWithPassword(email.trim(), password)) {
                is DeviceAuth.TokenResult.Success -> {
                    BcApi.saveLoginEmail(context, email)
                    BcApi.saveToken(context, t.accessToken)
                    BcApi.saveRefreshToken(context, t.refreshToken)
                    BcApi.saveTokenExpiry(context, t.expiresInSec)
                    status = "Token alındı, ortamlar keşfediliyor..."
                    lastToken = t.accessToken
                    envList = BcApi.discoverEnvironments(t.accessToken)
                    busy = false
                    // Ortam otomatik bulunamasa bile ekrana geç: kullanıcı ortam
                    // adını (ör. "Production") elle girip yoklayabilir.
                    selectedEnv = envList.firstOrNull()
                    step = Step.SelectEnvCompany
                    status = if (envList.isEmpty())
                        "⚠️ Otomatik ortam bulunamadı — ortam adınızı aşağıya yazıp 'Ortamı Bul' deyin"
                    else ""
                }
                is DeviceAuth.TokenResult.Failure -> { busy = false; status = "🔴 ${t.error}" }
                is DeviceAuth.TokenResult.Pending -> { busy = false; status = t.reason }
            }
        }
    }

    /**
     * Local WMS user (no email/AAD) sign-in. Requires that an admin/service AAD token is already
     * saved in BcApi prefs — that token is used as the carrier for the BC API call; BC server
     * verifies the local username/password and returns a resolved profile with roles.
     */
    fun startLocalSignIn() {
        scope.launch {
            if (!BcApi.hasToken(context)) {
                status = "🔴 Önce admin/servis erişim ayarlayın (Gelişmiş → token paste veya e-posta ile giriş)."
                return@launch
            }
            // Sanitize the username before interpolating into the OData URL key. Reject any
            // character outside the lowercase-alphanumeric + .-_ allowlist so an attacker
            // cannot break out of the single-quoted key and inject extra path segments or
            // OData functions. Matches BC's "DOPSWHS Local User".Username (Code[20]) shape.
            val rawUser = localUsername.trim().lowercase()
            if (!rawUser.matches(Regex("^[a-z0-9._-]{1,20}$"))) {
                status = "🔴 Kullanıcı adı geçersiz (sadece a-z, 0-9, . _ - karakterleri ve 1-20 karakter)."
                return@launch
            }
            // Even with allowlist there is no apostrophe possible, but escape per OData v4
            // spec (single-quote → double single-quote) for defence in depth and URL-encode.
            val safeKey = java.net.URLEncoder.encode(rawUser.replace("'", "''"), "UTF-8")
            busy = true; status = "WMS hesabı doğrulanıyor..."
            val body = JSONObject().apply { put("password", localPassword) }.toString()
            val r = BcApi.post(context, "localUsers('$safeKey')/Microsoft.NAV.verify", body)
            busy = false
            if (r.ok) {
                val resolved = BcApi.scalarValue(r.body)
                BcApi.saveLocalUser(context, rawUser, resolved)
                signedInAs = displayNameFromJson(resolved) ?: rawUser
                status = "🟢 $signedInAs olarak bağlandı."

                // Şirket keşfi ARKA PLANDA: operatör beklemesin. Aktif şirket
                // hemen kaydedilir, keşif bitince liste genişler ve seçim adımı
                // birden çok şirket varsa açılır.
                val activeCompany = BcApi.Company(
                    BcApi.getCompanyId(context), BcApi.getCompanyName(context), BcApi.getCompanyName(context),
                )
                if (BcApi.getAccessibleCompanies(context).isEmpty())
                    BcApi.saveAccessibleCompanies(context, listOf(activeCompany))

                val candidates = selectedEnv?.companies ?: listOf(activeCompany)
                companyDiscovering = true
                val accessible = runCatching {
                    BcApi.probeAccessibleCompanies(context, BcApi.getEnvironment(context), rawUser, candidates)
                }.getOrDefault(emptyList())
                companyDiscovering = false
                val finalList = accessible.ifEmpty { listOf(activeCompany) }
                BcApi.saveAccessibleCompanies(context, finalList)

                // Birden çok şirkete erişim varsa hangisine gireceğini SOR —
                // eskiden sessizce son şirkete giriliyordu, operatör yanlış
                // şirkette çalıştığını fark etmiyordu.
                if (finalList.size > 1) {
                    loginCompanies = finalList
                    step = Step.SelectCompanyAfterLogin
                } else
                    onConnected(true)
            } else {
                val msg = BcApi.errorMessage(r.body).ifBlank { "HTTP ${r.httpCode}" }
                status = "🔴 ${if (msg.contains("Invalid username")) "Kullanıcı adı veya şifre hatalı." else msg}"
            }
        }
    }

    fun startSignIn() {
        scope.launch {
            busy = true; status = "Giriş kodu alınıyor..."
            val res = DeviceAuth.requestCode(email.trim())
            busy = false
            res.onSuccess { code ->
                deviceCode = code
                step = Step.DeviceCode
                status = ""
                // (User taps "Tarayıcıda Aç" to open the browser — keeps the code visible in-app first.)
                // Poll for completion.
                scope.launch {
                    busy = true; status = "Tarayıcıda giriş bekleniyor..."
                    when (val t = DeviceAuth.pollForToken(code)) {
                        is DeviceAuth.TokenResult.Success -> {
                            BcApi.saveLoginEmail(context, email)
                            BcApi.saveToken(context, t.accessToken)
                    BcApi.saveRefreshToken(context, t.refreshToken)
                    BcApi.saveTokenExpiry(context, t.expiresInSec)
                            status = "Token alındı, ortamlar keşfediliyor..."
                            lastToken = t.accessToken
                            envList = BcApi.discoverEnvironments(t.accessToken)
                            busy = false
                            selectedEnv = envList.firstOrNull()
                            step = Step.SelectEnvCompany
                            if (envList.isEmpty()) {
                                status = "⚠️ Otomatik ortam bulunamadı — ortam adınızı yazıp 'Ortamı Bul' deyin"
                            } else {
                                status = ""
                            }
                        }
                        is DeviceAuth.TokenResult.Failure -> { busy = false; status = "🔴 ${t.error}" }
                        is DeviceAuth.TokenResult.Pending -> { busy = false; status = t.reason }
                    }
                }
            }.onFailure { busy = false; status = "🔴 ${it.message}" }
        }
    }

    // WMS giriş adımına gelince kayıtlı operatörleri çek (token varsa).
    LaunchedEffect(step) {
        if (step != Step.LocalUser || localUsers.isNotEmpty() || !BcApi.hasToken(context)) return@LaunchedEffect
        usersLoading = true
        // Sade sorgu: $select/$orderby bazı BC sürümlerinde bu entity'de hata
        // veriyor ve liste sessizce boş kalıyordu. Önce sade dene, olmazsa
        // seçili alanlarla tekrar dene.
        var page = runCatching { BcApi.getAllPages(context, "localUsers?\$top=200") }.getOrNull()
        if (page?.complete != true)
            page = runCatching {
                BcApi.getAllPages(context, "localUsers?\$select=username,displayName,disabled&\$top=200")
            }.getOrNull()

        if (page?.complete == true) {
            val list = page.rows.mapNotNull { o ->
                if (o.optBoolean("disabled", false)) return@mapNotNull null
                val u = o.optString("username").trim()
                if (u.isBlank()) null else LocalUserOption(u, o.optString("displayName").trim())
            }.sortedBy { it.displayName.ifBlank { it.username }.lowercase() }
            localUsers = list
            if (list.isEmpty()) {
                manualUserEntry = true
                usersError = "BC'de tanımlı WMS kullanıcısı yok. Yönetici \"Local WMS Users\" sayfasından oluşturmalı."
            } else usersError = ""
        } else {
            // Eksik listede var olan kullanıcıyı "yok" sayıp farklı kimlikle
            // giriş yaptırma; bağlantı düzelene kadar kesin olarak kapalı kal.
            manualUserEntry = false
            usersError = "Kullanıcı listesi alınamadı. Bağlantıyı kontrol edip tekrar deneyin."
        }
        usersLoading = false
    }

    if (showForgotPassword) {
        ForgotPasswordSheet(
            username = localUsername,
            onDismiss = { showForgotPassword = false },
        )
    }

    val loginBrand = resolveCompanyBrand(BcApi.getCompanyName(context), BuildConfig.FLAVOR)
    Column(Modifier.fillMaxSize().padding(20.dp).verticalScroll(rememberScrollState())) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            CompanyLogo(brand = loginBrand, height = 28.dp)
            Spacer(Modifier.width(12.dp))
            Column {
                Text("WMS Girişi", fontWeight = FontWeight.Bold, fontSize = 20.sp)
                Text("Hızlı ve güvenli depo erişimi", fontSize = 12.sp, color = Color.Gray)
            }
        }
        Spacer(Modifier.height(20.dp))

        AppUpdateCard()
        Spacer(Modifier.height(20.dp))

        when (step) {
            Step.Email -> {
                Text("Bu terminali bir kez bağlayın", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Spacer(Modifier.height(4.dp))
                Text(
                    "İlk bağlantıdan sonra güvenli oturum cihazda hatırlanır; her açılışta e-posta girmeniz gerekmez.",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(14.dp))
                if (editEmail) {
                    OutlinedTextField(
                        value = email,
                        onValueChange = { email = it },
                        label = { Text("Business Central e-postası") },
                        placeholder = { Text(BuildConfig.LOGIN_EMAIL_HINT) },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                } else {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = loginBrand.primary.copy(alpha = 0.10f)),
                        shape = RoundedCornerShape(14.dp),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Row(
                            Modifier.fillMaxWidth().padding(14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Box(
                                Modifier.size(38.dp).clip(RoundedCornerShape(11.dp))
                                    .background(loginBrand.primary.copy(alpha = 0.16f)),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text("@", fontWeight = FontWeight.Black, color = loginBrand.primary)
                            }
                            Spacer(Modifier.width(12.dp))
                            Column(Modifier.weight(1f)) {
                                Text("Bağlantı hesabı", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                Text(email, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                            }
                            TextButton(onClick = { editEmail = true }) { Text("Değiştir") }
                        }
                    }
                }
                Spacer(Modifier.height(10.dp))
                OutlinedTextField(
                    value = password, onValueChange = { password = it },
                    label = { Text("Microsoft hesabı şifresi") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    visualTransformation = PasswordVisualTransformation(),
                    supportingText = { Text("Şifre kaydedilmez; yalnız ilk bağlantı için kullanılır.") },
                    singleLine = true, modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.height(12.dp))
                Button(
                    onClick = { startPasswordSignIn() },
                    enabled = !busy && email.isNotBlank() && password.isNotBlank(),
                    modifier = Modifier.fillMaxWidth().height(52.dp)
                ) { Text(if (busy) "Bağlanıyor…" else "Bağlan ve Bu Cihazı Hatırla", fontWeight = FontWeight.Bold) }
                Spacer(Modifier.height(10.dp))
                OutlinedButton(
                    onClick = { startSignIn() },
                    enabled = !busy && email.isNotBlank(),
                    modifier = Modifier.fillMaxWidth().height(48.dp)
                ) { Text("Tarayıcıda Microsoft ile Giriş", fontSize = 13.sp) }
                Text(
                    "MFA açıksa bu seçeneği kullanın. Kod yalnız ilk cihaz kurulumunda istenir.",
                    fontSize = 10.sp,
                    color = Color.Gray,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().padding(top = 5.dp),
                )
                Spacer(Modifier.height(20.dp))
                HorizontalDivider()
                Spacer(Modifier.height(16.dp))
                OutlinedButton(
                    onClick = { step = Step.LocalUser; status = "" },
                    enabled = !busy,
                    modifier = Modifier.fillMaxWidth().height(48.dp)
                ) { Text("Bu Cihaz Zaten Kurulu — Depo Girişi", fontSize = 13.sp) }
                Spacer(Modifier.height(4.dp))
                Text(
                    "Servis bağlantısı daha önce yapıldıysa operatörünüzü seçin.",
                    fontSize = 10.sp,
                    color = Color.Gray
                )
            }

            Step.LocalUser -> {
                Text("Depo çalışanı girişi", fontWeight = FontWeight.Medium)
                Text(
                    "Kullanıcınızı seçin ve şifrenizi girin.",
                    fontSize = 11.sp,
                    color = Color.Gray
                )
                Spacer(Modifier.height(12.dp))
                if (!BcApi.hasToken(context)) {
                    Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFFFF3E0))) {
                        Column(Modifier.fillMaxWidth().padding(12.dp)) {
                            Text("Bu cihaz henüz kurulmamış", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                            Text(
                                "Bağlantı kurulumu için yöneticinizle iletişime geçin veya aşağıdaki gelişmiş ayarları açın.",
                                fontSize = 11.sp,
                                color = Color(0xFF6D4C41)
                            )
                        }
                    }
                    Spacer(Modifier.height(12.dp))
                }
                // Kayıtlı operatörler: BC'den çekilen listeden seç → şifre alanına odaklan.
                // Liste boşsa (API yok / yetki yok) elle yazma alanına düşer.
                if (localUsername.isBlank()) {
                    when {
                        usersLoading -> {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                                Spacer(Modifier.width(10.dp))
                                Text("Kullanıcılar yükleniyor...", fontSize = 12.sp, color = Color.Gray)
                            }
                            Spacer(Modifier.height(8.dp))
                        }
                        localUsers.isNotEmpty() -> {
                            Text("Kullanıcınızı seçin", fontSize = 12.sp, fontWeight = FontWeight.Medium, color = Color.Gray)
                            Spacer(Modifier.height(8.dp))

                            // Kurulum/saha testi için servis hesabıyla yönetici geçişi.
                            if (allowAdminBypass(BuildConfig.FLAVOR)) Card(
                                onClick = { startVerifiedAdminSession() },
                                enabled = !busy,
                                colors = CardDefaults.cardColors(containerColor = Color(0xFFFFF3E0)),
                                shape = RoundedCornerShape(12.dp),
                                modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
                            ) {
                                Row(
                                    Modifier.fillMaxWidth().padding(14.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Box(
                                        Modifier.size(38.dp).clip(RoundedCornerShape(12.dp))
                                            .background(Color(0xFFEF6C00).copy(alpha = 0.15f)),
                                        contentAlignment = Alignment.Center,
                                    ) {
                                        Text("A", fontSize = 17.sp, fontWeight = FontWeight.Bold, color = Color(0xFFEF6C00))
                                    }
                                    Spacer(Modifier.width(12.dp))
                                    Column(Modifier.weight(1f)) {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Text("Yönetici", fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
                                            Spacer(Modifier.width(6.dp))
                                            Surface(
                                                shape = RoundedCornerShape(50),
                                                color = Color(0xFFEF6C00).copy(alpha = 0.15f),
                                            ) {
                                                Text(
                                                    "destek",
                                                    Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                                                    fontSize = 10.sp,
                                                    fontWeight = FontWeight.SemiBold,
                                                    color = Color(0xFFBF360C),
                                                )
                                            }
                                        }
                                        Text(
                                            "Şifresiz, BC hesabıyla devam et",
                                            fontSize = 11.sp, color = Color.Gray,
                                        )
                                    }
                                    Text("›", fontSize = 20.sp, color = Color(0xFFEF6C00))
                                }
                            }

                            localUsers.forEach { u ->
                                Card(
                                    onClick = { localUsername = u.username; manualUserEntry = false; status = "" },
                                    colors = CardDefaults.cardColors(containerColor = Color(0xFFF3F0FF)),
                                    shape = RoundedCornerShape(12.dp),
                                    modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
                                ) {
                                    Row(
                                        Modifier.fillMaxWidth().padding(14.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                    ) {
                                        // Avatar: adın baş harfi (emoji yerine — kurumsal görünüm).
                                        Box(
                                            Modifier.size(38.dp).clip(RoundedCornerShape(12.dp))
                                                .background(Color(0xFF6C5CE7).copy(alpha = 0.15f)),
                                            contentAlignment = Alignment.Center,
                                        ) {
                                            Text(
                                                u.displayName.ifBlank { u.username }.take(1).uppercase(),
                                                fontSize = 17.sp,
                                                fontWeight = FontWeight.Bold,
                                                color = Color(0xFF6C5CE7),
                                            )
                                        }
                                        Spacer(Modifier.width(12.dp))
                                        Column(Modifier.weight(1f)) {
                                            Text(
                                                u.displayName.ifBlank { u.username },
                                                fontWeight = FontWeight.SemiBold,
                                                fontSize = 15.sp,
                                            )
                                            Text(u.username, fontSize = 11.sp, color = Color.Gray)
                                        }
                                        Text("›", fontSize = 20.sp, color = Color(0xFF6C5CE7))
                                    }
                                }
                            }
                            Spacer(Modifier.height(4.dp))
                            TextButton(onClick = { manualUserEntry = true }) {
                                Text("Listede yokum — elle yazayım", fontSize = 12.sp)
                            }
                        }
                        // Liste boş/çekilemedi: nedenini göster + yönetici yolu
                        // sun; elle yazma alanı zaten aşağıda görünür.
                        else -> {
                            if (usersError.isNotBlank()) {
                                Card(
                                    colors = CardDefaults.cardColors(containerColor = Color(0xFFFFF8E1)),
                                    shape = RoundedCornerShape(12.dp),
                                    modifier = Modifier.fillMaxWidth(),
                                ) {
                                    Text(
                                        operatorFacingStatus(usersError),
                                        Modifier.padding(12.dp),
                                        fontSize = 11.sp,
                                        color = Color(0xFF6D4C41),
                                    )
                                }
                                Spacer(Modifier.height(10.dp))
                            }
                            if (allowAdminBypass(BuildConfig.FLAVOR)) {
                                OutlinedButton(
                                    onClick = { startVerifiedAdminSession() },
                                    enabled = !busy,
                                    modifier = Modifier.fillMaxWidth().height(48.dp),
                                ) { Text("Yönetici olarak devam et", fontSize = 13.sp) }
                                Spacer(Modifier.height(10.dp))
                            }
                        }
                    }
                }

                // Seçilmiş kullanıcı rozeti + değiştir
                if (localUsername.isNotBlank() && !manualUserEntry) {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = Color(0xFFEDE7F6)),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Row(
                            Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            val disp = localUsers.firstOrNull { it.username == localUsername }?.displayName.orEmpty()
                            Box(
                                Modifier.size(34.dp).clip(RoundedCornerShape(10.dp))
                                    .background(Color(0xFF6C5CE7).copy(alpha = 0.18f)),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    disp.ifBlank { localUsername }.take(1).uppercase(),
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color(0xFF6C5CE7),
                                )
                            }
                            Spacer(Modifier.width(10.dp))
                            Column(Modifier.weight(1f)) {
                                Text(disp.ifBlank { localUsername }, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                                if (disp.isNotBlank()) Text(localUsername, fontSize = 11.sp, color = Color.Gray)
                            }
                            TextButton(onClick = { localUsername = ""; localPassword = ""; status = "" }) {
                                Text("Değiştir", fontSize = 12.sp)
                            }
                        }
                    }
                    Spacer(Modifier.height(10.dp))
                }

                if (manualUserEntry) {
                    OutlinedTextField(
                        value = localUsername, onValueChange = { localUsername = it },
                        label = { Text("WMS Kullanıcı Adı") },
                        placeholder = { Text("wms-op-01") },
                        singleLine = true, modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(Modifier.height(8.dp))
                }

                if (localUsername.isNotBlank() || manualUserEntry) {
                    OutlinedTextField(
                        value = localPassword, onValueChange = { localPassword = it },
                        label = { Text("Şifre") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                        visualTransformation = if (showPassword) androidx.compose.ui.text.input.VisualTransformation.None
                            else PasswordVisualTransformation(),
                        trailingIcon = {
                            TextButton(onClick = { showPassword = !showPassword }) {
                                Text(if (showPassword) "Gizle" else "Göster", fontSize = 12.sp)
                            }
                        },
                        singleLine = true, modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(Modifier.height(16.dp))
                    Button(
                        onClick = { startLocalSignIn() },
                        enabled = !busy && !companyDiscovering && localUsername.isNotBlank() && localPassword.isNotBlank() && BcApi.hasToken(context),
                        modifier = Modifier.fillMaxWidth().height(52.dp)
                    ) {
                        Text(
                            when {
                                busy -> "..."
                                companyDiscovering -> "Şirketler kontrol ediliyor..."
                                else -> "Bağlan"
                            },
                            fontWeight = FontWeight.Bold,
                        )
                    }
                    Spacer(Modifier.height(4.dp))
                    TextButton(
                        onClick = { showForgotPassword = true },
                        modifier = Modifier.align(Alignment.CenterHorizontally),
                    ) { Text("Şifremi unuttum", fontSize = 12.sp, color = Color(0xFF6C5CE7)) }
                }
                Spacer(Modifier.height(4.dp))
                TextButton(onClick = { step = Step.Email; status = ""; manualUserEntry = false }) { Text("‹ Geri (e-posta girişine dön)") }
                // Ortam (sandbox) değiştirmek için eskiden baştan e-posta girişi
                // yapmak gerekiyordu — oysa AAD token'ı zaten kayıtlı. Kayıtlı
                // token'la ortamları doğrudan yeniden keşfedip seçiciye geçiyoruz.
                if (BcApi.hasToken(context)) {
                    TextButton(
                        enabled = !busy,
                        onClick = {
                            scope.launch {
                                busy = true; status = "Ortamlar aranıyor…"
                                val token = BcApi.getToken(context)
                                envList = runCatching { BcApi.discoverEnvironments(token) }
                                    .getOrDefault(emptyList())
                                lastToken = token
                                selectedEnv = envList.firstOrNull {
                                    it.environment == BcApi.getEnvironment(context)
                                } ?: envList.firstOrNull()
                                busy = false
                                step = Step.SelectEnvCompany
                                status = if (envList.isEmpty())
                                    "Ortam listelenemedi — ortam adını yazıp 'Ortamı Bul' deyin"
                                else ""
                            }
                        },
                    ) { Text("Ortam / sandbox değiştir (${BcApi.getEnvironment(context)})", fontSize = 12.sp) }
                }
                // Not: yönetici girişi artık kullanıcı listesinin başındaki
                // "Yönetici (demo sürüm)" kartından yapılıyor.
            }

            // Operatör birden çok şirkete erişebiliyorsa hangisinde çalışacağını
            // giriş anında seçsin — yanlış şirkette iş yapmanın önüne geçer.
            Step.SelectCompanyAfterLogin -> {
                Text("Hangi şirkette çalışacaksınız?", fontWeight = FontWeight.Bold, fontSize = 17.sp)
                if (signedInAs.isNotBlank()) {
                    Spacer(Modifier.height(4.dp))
                    Text("$signedInAs olarak girdiniz", fontSize = 12.sp, color = Color.Gray)
                }
                Spacer(Modifier.height(14.dp))
                val activeId = BcApi.getCompanyId(context)
                loginCompanies.forEach { c ->
                    val isActive = c.id.equals(activeId, ignoreCase = true)
                    Card(
                        onClick = {
                            onConnected(false)
                            scope.launch {
                                busy = true
                                status = "${c.displayName} doğrulanıyor..."
                                BcApi.setCompany(context, c.id, c.displayName)
                                val result = BcApi.testConnection(context)
                                busy = false
                                if (result.ok) {
                                    status = "🟢 ${c.displayName} şirketine bağlandı."
                                    onConnected(true)
                                } else {
                                    status = "🔴 ${BcApi.connectionFailureMessage(result)}"
                                    onConnected(false)
                                }
                            }
                        },
                        enabled = !busy,
                        colors = CardDefaults.cardColors(
                            containerColor = if (isActive) Color(0xFFEDE7F6) else Color(0xFFF3F0FF),
                        ),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
                    ) {
                        Row(
                            Modifier.fillMaxWidth().padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(Modifier.weight(1f)) {
                                Text(c.displayName, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
                                if (isActive)
                                    Text("son kullandığınız şirket", fontSize = 11.sp, color = Color(0xFF6C5CE7))
                            }
                            Text("›", fontSize = 20.sp, color = Color(0xFF6C5CE7))
                        }
                    }
                }
                Spacer(Modifier.height(6.dp))
                Text(
                    "Şirketi sonradan ana ekrandaki \"Şirket Değiştir\" ile de değiştirebilirsiniz.",
                    fontSize = 11.sp, color = Color.Gray,
                )
            }

            Step.DeviceCode -> {
                val code = deviceCode
                Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFEDE7F6))) {
                    Column(Modifier.fillMaxWidth().padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("Tarayıcıda şu kodu girin:", fontSize = 13.sp)
                        Spacer(Modifier.height(8.dp))
                        Text(code?.userCode ?: "", fontWeight = FontWeight.Bold, fontSize = 30.sp, color = Color(0xFF4527A0))
                        Spacer(Modifier.height(8.dp))
                        Text(code?.verificationUri ?: "", fontSize = 13.sp, color = Color(0xFF4527A0), textAlign = TextAlign.Center)
                    }
                }
                Spacer(Modifier.height(12.dp))
                OutlinedButton(
                    onClick = {
                        val uri = code?.verificationUri?.trim().orEmpty()
                        if (uri.isBlank()) {
                            status = "HATA: Giriş bağlantısı hazır değil. Geri dönüp yeniden deneyin."
                        } else if (runCatching {
                                context.startActivity(
                                    Intent(Intent.ACTION_VIEW, Uri.parse(uri))
                                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                                )
                            }.isFailure
                        ) {
                            status = "HATA: Tarayıcı açılamadı. Yukarıdaki adresi tarayıcıya elle girin."
                        }
                    },
                    enabled = !busy,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("Tarayıcıda Aç") }
                Spacer(Modifier.height(12.dp))
                if (busy) LinearProgressIndicator(Modifier.fillMaxWidth())
                Spacer(Modifier.height(8.dp))
                TextButton(onClick = { step = Step.Email; status = "" }) { Text("‹ Geri") }
            }

            Step.SelectEnvCompany -> {
                Text("Ortam seçin", fontWeight = FontWeight.Medium)
                Spacer(Modifier.height(6.dp))
                // Otomatik keşif her müşterinin ortam adını bilemez (BADE =
                // "Production" vb.) — kullanıcı ortam adını elle yoklayabilir.
                Row(verticalAlignment = Alignment.CenterVertically) {
                    OutlinedTextField(
                        value = manualEnv, onValueChange = { manualEnv = it },
                    label = { Text("Ortam adı (ör. ${BuildConfig.BC_DEFAULT_ENVIRONMENT})") },
                        singleLine = true, modifier = Modifier.weight(1f),
                    )
                    Spacer(Modifier.width(8.dp))
                    Button(
                        enabled = !busy && manualEnv.isNotBlank() && lastToken.isNotBlank(),
                        onClick = {
                            scope.launch {
                                busy = true; status = "'${manualEnv.trim()}' yoklanıyor..."
                                val ec = BcApi.probeEnvironment(BcApi.getTenant(context), manualEnv.trim(), lastToken)
                                busy = false
                                if (ec != null) {
                                    if (envList.none { it.environment == ec.environment }) envList = envList + ec
                                    selectedEnv = ec
                                    status = "🟢 ${ec.environment} bulundu (${ec.companies.size} şirket)"
                                } else status = "🔴 '${manualEnv.trim()}' bulunamadı ya da şirket yok — ortam adını kontrol edin"
                            }
                        },
                    ) { Text("Bul") }
                }
                Spacer(Modifier.height(10.dp))
                envList.forEach { ec ->
                    val sel = ec.environment == selectedEnv?.environment
                    Card(
                        onClick = { selectedEnv = ec },
                        modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
                        colors = CardDefaults.cardColors(containerColor = if (sel) Color(0xFFD1C4E9) else Color(0xFFF5F5F5))
                    ) {
                        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                            RadioButton(selected = sel, onClick = { selectedEnv = ec })
                            Text("${ec.environment} (${ec.companies.size} şirket)", fontWeight = FontWeight.Medium)
                        }
                    }
                }
                Spacer(Modifier.height(12.dp))
                Text("Şirket seçin", fontWeight = FontWeight.Medium)
                Spacer(Modifier.height(6.dp))
                selectedEnv?.companies?.forEach { c ->
                    Card(
                        onClick = {
                            scope.launch {
                                onConnected(false)
                                busy = true; status = "Bağlanılıyor: ${c.displayName}..."
                                BcApi.setEnvironment(context, selectedEnv!!.environment)
                                BcApi.setCompany(context, c.id, c.displayName)
                                val r = BcApi.testConnection(context)
                                busy = false
                                if (r.ok) {
                                    // ELOG multi-company: WMS kullanıcı girişi ATLANSA bile (admin/AAD)
                                    // üstteki şirket değiştirici çalışsın diye erişilebilir (WMS kurulu)
                                    // şirketleri şimdi hesapla/sakla. WMS kullanıcı girişi yapılırsa
                                    // orada kullanıcı-bazlı daha dar listeyle üzerine yazılır.
                                    val wmsCompanies = runCatching {
                                        BcApi.probeWmsCompanies(context, selectedEnv!!.environment, selectedEnv!!.companies)
                                    }.getOrDefault(emptyList())
                                    BcApi.saveAccessibleCompanies(
                                        context,
                                        wmsCompanies.ifEmpty { listOf(c) },
                                    )
                                    // Paylaşımlı BC lisansı: ortam bağlantısı servis hesabıyla
                                    // yapıldı; oturum ancak WMS operatörü kendi kullanıcı adı +
                                    // şifresiyle doğrulanınca açılır (BC → WMS Users / Local User).
                                    status = "🟢 Ortam bağlandı: ${selectedEnv!!.environment} / ${c.displayName} — şimdi WMS kullanıcınızla giriş yapın"
                                    step = Step.LocalUser
                                } else { status = "🔴 ${BcApi.connectionFailureMessage(r)}"; onConnected(false) }
                            }
                        },
                        modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp), shape = RoundedCornerShape(10.dp)
                    ) {
                        Column(Modifier.padding(12.dp)) {
                            Text(c.displayName, fontWeight = FontWeight.Medium)
                            Text("Seçmek için dokunun →", fontSize = 11.sp, color = Color(0xFF6A1B9A))
                        }
                    }
                }
                // Vazgeçme yolu: bu adımda şirket seçmeden çıkılamıyordu, ortamı
                // yanlışlıkla açan operatör ekranda kilitli kalıyordu.
                if (BcApi.hasToken(context)) {
                    Spacer(Modifier.height(8.dp))
                    TextButton(onClick = { step = Step.LocalUser; status = "" }) {
                        Text("‹ Vazgeç (WMS girişine dön)", fontSize = 12.sp)
                    }
                }
            }
        }

        Spacer(Modifier.height(16.dp))
        StatusText(status)

        Spacer(Modifier.height(24.dp))
        // Servis hesabı belirteci bir operatör ayarı değildir. Müşteri saha
        // sürümünde yanlışlıkla paylaşılmasını/değiştirilmesini önlemek için
        // yalnızca geliştirme varyantlarında gösterilir.
        if (!shouldForceProductionFlow(BuildConfig.FLAVOR)) {
            TextButton(onClick = { showAdvanced = !showAdvanced }) { Text(if (showAdvanced) "Token girişini gizle" else "Gelişmiş: token ile giriş") }
            if (showAdvanced) TokenPasteFallback(onConnected = onConnected)
        }
    }
}

/** Parses the inner displayName from the resolveProfile JSON envelope. */
private fun displayNameFromJson(jsonText: String): String? = try {
    JSONObject(jsonText.replace("{,", "{")).optString("displayName").ifBlank { null }
} catch (_: Exception) { null }

/** Advanced fallback: paste an az-CLI access token directly (the prior flow). */
@Composable
private fun TokenPasteFallback(onConnected: (Boolean) -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var token by remember { mutableStateOf("") }
    var status by remember { mutableStateOf("") }
    Column(Modifier.fillMaxWidth()) {
        Text("az account get-access-token --resource https://api.businesscentral.dynamics.com --query accessToken -o tsv",
            fontSize = 10.sp, color = Color.Gray)
        Spacer(Modifier.height(6.dp))
        OutlinedTextField(token, { token = it }, label = { Text("Erişim belirteci") }, modifier = Modifier.fillMaxWidth(), maxLines = 3)
        Spacer(Modifier.height(8.dp))
        Button(enabled = token.isNotBlank(), onClick = {
            BcApi.saveToken(context, token)
            scope.launch {
                BcApi.ensurePreferredCompany(context)
                val r = BcApi.testConnection(context)
                status = if (r.ok) "🟢 Bağlandı" else "🔴 ${BcApi.connectionFailureMessage(r)}"
                onConnected(r.ok)
            }
        }) { Text("Token ile Bağlan") }
        StatusText(status)
    }
}

/**
 * "Şifremi unuttum" — WMS operatör şifreleri BC'de hash'li tutulur, terminalden
 * sıfırlanamaz. Bu sayfa operatöre kimden yardım isteyeceğini net söyler ve
 * yöneticiye BC'deki adımı hatırlatır.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ForgotPasswordSheet(username: String, onDismiss: () -> Unit) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(bottom = 28.dp)) {
            Text("Şifremi unuttum", fontWeight = FontWeight.Bold, fontSize = 18.sp)
            Spacer(Modifier.height(6.dp))
            Text(
                if (username.isNotBlank()) "Kullanıcı: $username" else "WMS operatör şifresi",
                fontSize = 12.sp, color = Color.Gray,
            )
            Spacer(Modifier.height(16.dp))
            Card(
                colors = CardDefaults.cardColors(containerColor = Color(0xFFFFF8E1)),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(Modifier.padding(14.dp)) {
                    Text("Şifreniz terminalden sıfırlanamaz", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "Güvenlik gereği WMS şifreleri Business Central'da şifrelenmiş saklanır. " +
                            "Depo sorumlunuz size yeni bir şifre belirlemeli.",
                        fontSize = 12.sp, color = Color(0xFF6D4C41),
                    )
                }
            }
            Spacer(Modifier.height(16.dp))
            Text("Depo sorumlusu için adımlar", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
            Spacer(Modifier.height(8.dp))
            listOf(
                "1. Business Central'da \"Local WMS Users\" sayfasını açın",
                "2. İlgili kullanıcıyı seçip Düzenle deyin",
                "3. \"Şifre\" bölümüne yeni şifreyi yazın (kaydedilince hash'lenir)",
                "4. Yeni şifreyi operatöre güvenli kanaldan iletin",
            ).forEach {
                Text(it, fontSize = 12.sp, modifier = Modifier.padding(vertical = 3.dp))
            }
            Spacer(Modifier.height(20.dp))
            Button(onClick = onDismiss, modifier = Modifier.fillMaxWidth().height(48.dp)) {
                Text("Anladım")
            }
        }
    }
}
