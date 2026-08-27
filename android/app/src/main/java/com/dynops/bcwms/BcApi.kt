package com.dynops.bcwms

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

/**
 * Business Central SaaS API client.
 * Token bir kez girilir, SharedPreferences'ta kalici saklanir, tum ekranlar otomatik kullanir.
 */
object BcApi {
    // Multi-tenant: uygulama artık tek bir tenant'a sabitlenmez. Giriş
    // "common" authority ile yapılır (aşağıda DeviceAuth), gerçek tenant ID
    // token'dan (tid claim) çıkarılıp cihaza kaydedilir; tüm BC API çağrıları
    // o kayıtlı tenant'ı kullanır. Böylece her müşteri için ayrı APK gerekmez.
    // FALLBACK_TENANT yalnızca token okunamazsa / geçiş dönemindeki eski
    // kurulumlar için — DynamicsOps sandbox'ı.
    val FALLBACK_TENANT = BuildConfig.BC_FALLBACK_TENANT
    // Multi-tenant public client. AzureADMultipleOrgs olarak kayıtlı olmalı;
    // her müşteri yöneticisi kendi tenant'ında bu client'a onay verir.
    val CLIENT_ID = BuildConfig.BC_CLIENT_ID  // Tenant flavor public client (device-code)
    const val BC_RESOURCE = "https://api.businesscentral.dynamics.com"

    // Defaults (used until the user picks an environment/company after email sign-in).
    val DEFAULT_ENVIRONMENT = BuildConfig.BC_DEFAULT_ENVIRONMENT
    val DEFAULT_COMPANY_ID = BuildConfig.BC_DEFAULT_COMPANY_ID
    val DEFAULT_COMPANY_NAME = BuildConfig.BC_DEFAULT_COMPANY_NAME

    /** Sign-in sonrası yoklanan ortam adları. Multi-tenant: her müşterinin
     *  ortam adı farklı olabildiğinden en yaygın adlar denenir; bulunamazsa
     *  kullanıcı LoginFlow'da ortam adını elle girebilir (probeEnvironment). */
    val KNOWN_ENVIRONMENTS = buildList {
        add(DEFAULT_ENVIRONMENT)
        addAll(listOf("Sandbox", "SandboxUS", "CustomerSandbox"))
        if (BuildConfig.BC_ALLOW_PRODUCTION) add("Production")
    }.distinct()

    private const val PREFS = "bcwms_prefs"
    private const val KEY_TOKEN = "bc_access_token"
    private const val KEY_REFRESH = "bc_refresh_token"
    private const val KEY_EXPIRY = "bc_token_expiry_ms"
    private const val KEY_ENV = "bc_environment"
    private const val KEY_COMPANY_ID = "bc_company_id"
    private const val KEY_COMPANY_NAME = "bc_company_name"
    private const val KEY_LOCAL_USER = "local_user_id"
    private const val KEY_LOCAL_PROFILE = "local_user_profile_json"
    private const val KEY_ADMIN_TEST_SESSION = "admin_test_session"
    private const val KEY_BC_USER = "bc_user_id"
    private const val KEY_TENANT = "bc_tenant_id"
    private const val KEY_LOGIN_EMAIL = "login_email"

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    // ---- Tenant (runtime, multi-tenant) ----
    /** Kayıtlı tenant ID; henüz giriş yapılmadıysa fallback (eski davranış). */
    fun getTenant(context: Context): String = prefs(context).getString(KEY_TENANT, FALLBACK_TENANT) ?: FALLBACK_TENANT
    fun setTenant(context: Context, tenantId: String) {
        if (tenantId.isNotBlank()) prefs(context).edit().putString(KEY_TENANT, tenantId).apply()
    }

    /**
     * Access token'ın "tid" (tenant id) claim'ini okur ve kaydeder. Giriş
     * başarılı olunca çağrılır — sonraki tüm BC çağrıları doğru tenant'a gider.
     * JWT payload = base64url(2. bölüm); tenant çözülemezse kayıt değişmez.
     */
    fun captureTenantFromToken(context: Context, accessToken: String) {
        val tid = tenantIdFromJwt(accessToken)
        if (!tid.isNullOrBlank()) setTenant(context, tid)
    }

    private fun tenantIdFromJwt(jwt: String): String? = try {
        val parts = jwt.split(".")
        if (parts.size < 2) null else {
            val payload = String(
                android.util.Base64.decode(parts[1], android.util.Base64.URL_SAFE or android.util.Base64.NO_PADDING or android.util.Base64.NO_WRAP)
            )
            JSONObject(payload).optString("tid").takeIf { it.isNotBlank() }
        }
    } catch (e: Exception) { null }

    // ---- Environment / company selection (runtime-configurable) ----
    fun getEnvironment(context: Context): String = prefs(context).getString(KEY_ENV, DEFAULT_ENVIRONMENT) ?: DEFAULT_ENVIRONMENT
    fun getCompanyId(context: Context): String = prefs(context).getString(KEY_COMPANY_ID, DEFAULT_COMPANY_ID) ?: DEFAULT_COMPANY_ID
    fun getCompanyName(context: Context): String = prefs(context).getString(KEY_COMPANY_NAME, DEFAULT_COMPANY_NAME) ?: DEFAULT_COMPANY_NAME

    fun saveLoginEmail(context: Context, email: String) {
        if (email.isNotBlank()) prefs(context).edit().putString(KEY_LOGIN_EMAIL, email.trim()).apply()
    }

    fun getLoginEmail(context: Context, fallback: String): String =
        prefs(context).getString(KEY_LOGIN_EMAIL, fallback)?.takeIf { it.isNotBlank() } ?: fallback

    fun setEnvironment(context: Context, env: String) { prefs(context).edit().putString(KEY_ENV, env).apply() }
    fun setCompany(context: Context, id: String, name: String) {
        prefs(context).edit().putString(KEY_COMPANY_ID, id).putString(KEY_COMPANY_NAME, name).apply()
    }

    /**
     * Resolves a flavor's preferred company by name before the first API call.
     *
     * BADE used to inherit the shared CRONUS UUID. A token-paste or an upgraded
     * installation could therefore connect successfully to CRONUS without ever
     * showing the company picker. We only auto-correct an unset company or that
     * legacy CRONUS selection; an operator's deliberate BS/BADE company choice
     * remains untouched.
     */
    suspend fun ensurePreferredCompany(context: Context): Boolean = withContext(Dispatchers.IO) {
        val token = getToken(context)
        if (token.isBlank() || DEFAULT_COMPANY_NAME.isBlank()) return@withContext false

        val storedId = prefs(context).getString(KEY_COMPANY_ID, null).orEmpty()
        val storedName = prefs(context).getString(KEY_COMPANY_NAME, null).orEmpty()
        val legacyCronus = DEFAULT_COMPANY_NAME != "CRONUS USA, Inc." &&
            storedName.equals("CRONUS USA, Inc.", ignoreCase = true)
        if (storedId.isNotBlank() && storedName.isNotBlank() && !legacyCronus)
            return@withContext false

        val env = getEnvironment(context)
        val response = httpGet(companiesUrl(getTenant(context), env), token)
        if (!response.ok) return@withContext false
        val preferred = parseValueArray(response.body)
            .map {
                Company(
                    it.optString("id"),
                    it.optString("name"),
                    it.optString("displayName").ifBlank { it.optString("name") },
                )
            }
            .firstOrNull {
                it.displayName.equals(DEFAULT_COMPANY_NAME, ignoreCase = true) ||
                    it.name.equals(DEFAULT_COMPANY_NAME, ignoreCase = true)
            }
            ?: return@withContext false

        setCompany(context, preferred.id, preferred.displayName)
        saveAccessibleCompanies(context, listOf(preferred))
        true
    }

    // ---- Multi-company switcher (BADE / BS / ... aynı ortamda) ----
    // ELOG: operatör aynı ortamdaki farklı BC şirketleri arasında login yapmadan
    // geçebilsin. Yalnız erişilebilir (WMS kurulu + operatörün localUser'ı olan)
    // şirketler saklanır; PIM gibi WMS'siz/kullanıcısız şirketler dışarıda kalır.
    private const val KEY_ACCESSIBLE_COMPANIES = "accessible_companies_json"

    /** Girişte hesaplanan erişilebilir şirketleri (aktif ortam için) saklar. */
    fun saveAccessibleCompanies(context: Context, companies: List<Company>) {
        val arr = JSONArray()
        companies.forEach { arr.put(JSONObject().apply { put("id", it.id); put("name", it.name); put("displayName", it.displayName) }) }
        prefs(context).edit().putString(KEY_ACCESSIBLE_COMPANIES, arr.toString()).apply()
    }

    fun getAccessibleCompanies(context: Context): List<Company> {
        val raw = prefs(context).getString(KEY_ACCESSIBLE_COMPANIES, null) ?: return emptyList()
        return runCatching {
            val arr = JSONArray(raw)
            (0 until arr.length()).map {
                val o = arr.getJSONObject(it)
                Company(o.optString("id"), o.optString("name"), o.optString("displayName").ifBlank { o.optString("name") })
            }
        }.getOrDefault(emptyList())
    }

    /**
     * Verilen şirket listesinden operatörün erişebildiklerini döndürür.
     * Kriter: o şirketin DOPSWHS WMS API'sinde `localUsers('<username>')` kaydı
     * bulunur (HTTP 200) → WMS kurulu VE kullanıcı var. WMS yok (404 host/app)
     * ya da kullanıcı yok (404) → şirket elenir. Aktif token ile çağrılır.
     */
    suspend fun probeAccessibleCompanies(
        context: Context, env: String, username: String, companies: List<Company>,
    ): List<Company> = withContext(Dispatchers.IO) {
        val token = getToken(context)
        val tenant = getTenant(context)
        val safeUser = java.net.URLEncoder.encode(username.trim().lowercase().replace("'", "''"), "UTF-8")
        // PARALEL yoklama: sıralı filter'da 10 şirket = 10 ardışık istek (~3-6 sn).
        // Hepsi aynı anda gider, süre en yavaş isteğe iner.
        companies.map { c ->
            async {
                val base = "https://api.businesscentral.dynamics.com/v2.0/$tenant/$env/api/dynops/warehouse/v2.0/companies(${c.id})"
                // Önce kullanıcı-bazlı yokla. Operatörün o şirkette localUser kaydı
                // yoksa da şirket ERİŞİLEBİLİR sayılır (WMS kurulu olması yeterli):
                // BC'de tek kullanıcı kaydıyla birden çok şirkete girilebiliyor,
                // eski katı kriter bu şirketleri listeden düşürüyordu.
                val hasUser = httpGet("$base/localUsers('$safeUser')", token).ok
                val wmsInstalled = hasUser || httpGet("$base/localUsers?\$top=1", token).ok
                if (wmsInstalled) c else null
            }
        }.awaitAll().filterNotNull()
    }

    /**
     * WMS kullanıcı adı olmadan (AAD/admin girişi) erişilebilir şirketleri bulur:
     * kriter yalnız "DOPSWHS WMS API'si o şirkette yanıt veriyor" — localUsers
     * entity set'i sorgulanır (HTTP 200 → WMS kurulu). PIM gibi WMS'siz şirketler
     * elenir; kullanıcı-bazlı filtre yoktur (username bilinmiyor).
     */
    suspend fun probeWmsCompanies(
        context: Context, env: String, companies: List<Company>,
    ): List<Company> = withContext(Dispatchers.IO) {
        val token = getToken(context)
        val tenant = getTenant(context)
        // Paralel yoklama (bkz. probeAccessibleCompanies).
        companies.map { c ->
            async {
                val url = "https://api.businesscentral.dynamics.com/v2.0/$tenant/$env/api/dynops/warehouse/v2.0/companies(${c.id})/localUsers?\$top=1"
                if (httpGet(url, token).ok) c else null
            }
        }.awaitAll().filterNotNull()
    }

    /**
     * Erişilebilir şirket listesi boşsa (ör. login akışı switcher eklenmeden
     * yapılmış) mevcut ortamdaki tüm şirketleri çekip WMS kurulu olanları
     * hesaplar ve saklar. Home ekranı ilk açılışta çağırır. Zaten liste doluysa
     * ya da token yoksa no-op. Sonuç doluysa true döner (UI tazelemek için).
     */
    suspend fun refreshAccessibleCompaniesIfEmpty(context: Context): Boolean {
        if (getAccessibleCompanies(context).isNotEmpty()) return false
        return rediscoverAccessibleCompanies(context)
    }

    /**
     * Erişilebilir şirketleri KOŞULSUZ yeniden keşfeder ve kaydeder.
     * Şirket değiştirici her açıldığında çağrılır: kayıtlı liste eski olabilir
     * (yeni şirket eklenmiş ya da ilk keşif tek şirketle sonuçlanmış olabilir).
     * Dönüş: birden çok şirkete erişim var mı.
     */
    suspend fun rediscoverAccessibleCompanies(context: Context): Boolean = withContext(Dispatchers.IO) {
        val token = getToken(context)
        if (token.isBlank()) return@withContext false
        val tenant = getTenant(context)
        val env = getEnvironment(context)
        val r = httpGet(companiesUrl(tenant, env), token)
        if (!r.ok) return@withContext false
        val all = parseValueArray(r.body).map {
            Company(it.optString("id"), it.optString("name"), it.optString("displayName").ifBlank { it.optString("name") })
        }
        // WMS operatörü girişliyse kullanıcı-bazlı, değilse yalnız WMS-kurulu filtresi.
        val localUser = getLocalUser(context)
        val accessible = if (localUser.isNotBlank())
            runCatching { probeAccessibleCompanies(context, env, localUser, all) }.getOrDefault(emptyList())
        else
            runCatching { probeWmsCompanies(context, env, all) }.getOrDefault(emptyList())
        val result = accessible.ifEmpty {
            listOf(Company(getCompanyId(context), getCompanyName(context), getCompanyName(context)))
        }
        saveAccessibleCompanies(context, result)
        result.size > 1
    }

    private fun customApiBase(context: Context) =
        "https://api.businesscentral.dynamics.com/v2.0/${getTenant(context)}/${getEnvironment(context)}/api/dynops/warehouse/v2.0/companies(${getCompanyId(context)})"

    private fun standardApiBase(context: Context) =
        "https://api.businesscentral.dynamics.com/v2.0/${getTenant(context)}/${getEnvironment(context)}/api/v2.0/companies(${getCompanyId(context)})"

    private fun customApiMetadataUrl(context: Context) =
        "https://api.businesscentral.dynamics.com/v2.0/${getTenant(context)}/${getEnvironment(context)}/api/dynops/warehouse/v2.0/\$metadata"

    /** Standard companies endpoint — discovery için tenant'ı açıkça alır (giriş
     *  anında henüz kayıtlı değildir; token'dan çözülüp buraya geçirilir). */
    fun companiesUrl(tenant: String, env: String) =
        "https://api.businesscentral.dynamics.com/v2.0/$tenant/$env/api/v2.0/companies?\$select=id,name,displayName"

    // ---- Token persistence ----
    fun saveToken(context: Context, token: String) {
        val t = token.trim()
        prefs(context).edit().putString(KEY_TOKEN, t).apply()
        // Multi-tenant: her token kaydında gerçek tenant'ı (tid claim) yakala —
        // device-code, ROPC, refresh ve manuel token-paste yollarının hepsi
        // buradan geçtiği için tek noktada doğru tenant sabitlenir.
        captureTenantFromToken(context, t)
    }

    fun getToken(context: Context): String = prefs(context).getString(KEY_TOKEN, "") ?: ""

    fun hasToken(context: Context): Boolean = getToken(context).isNotBlank()

    // Çıkış: tenant/env/company da temizlenir — farklı müşteri hesabıyla
    // yeniden girildiğinde eski tenant'a takılıp kalmayı önler (multi-tenant).
    fun clearToken(context: Context) {
        prefs(context).edit()
            .remove(KEY_TOKEN).remove(KEY_REFRESH).remove(KEY_BC_USER)
            .remove(KEY_TENANT).remove(KEY_ENV).remove(KEY_COMPANY_ID).remove(KEY_COMPANY_NAME)
            .remove(KEY_ADMIN_TEST_SESSION)
            .remove(KEY_ACCESSIBLE_COMPANIES)
            .apply()
    }

    fun saveRefreshToken(context: Context, token: String) {
        if (token.isBlank()) return
        prefs(context).edit().putString(KEY_REFRESH, token.trim()).apply()
    }

    fun getRefreshToken(context: Context): String = prefs(context).getString(KEY_REFRESH, "") ?: ""

    /** Persists the absolute epoch-ms at which the current access token expires. */
    fun saveTokenExpiry(context: Context, expiresInSec: Int) {
        val at = System.currentTimeMillis() + expiresInSec * 1000L
        prefs(context).edit().putLong(KEY_EXPIRY, at).apply()
    }

    private fun tokenExpiryMs(context: Context): Long = prefs(context).getLong(KEY_EXPIRY, 0L)

    /**
     * Proactively renews the access token when it is within [skewMs] of expiry (or already
     * expired) and a refresh token is available. Runs before each request so an operator's
     * session lasts as long as the AAD refresh token (hours → all shift), not the ~1h access
     * token. Silent no-op when there is nothing to refresh or the refresh is rejected — the
     * request then proceeds and the reactive 401 path is the final fallback.
     */
    private fun ensureFreshToken(context: Context, skewMs: Long = 5 * 60 * 1000L) {
        val expiry = tokenExpiryMs(context)
        if (expiry == 0L || System.currentTimeMillis() < expiry - skewMs) return
        synchronized(this) {
            // Re-check inside the lock: another thread may have just refreshed.
            if (System.currentTimeMillis() < tokenExpiryMs(context) - skewMs) return
            val rt = getRefreshToken(context)
            if (rt.isBlank()) return
            val refreshed = DeviceAuth.refreshAccessToken(rt, getTenant(context)) ?: return
            saveToken(context, refreshed.first)
            saveRefreshToken(context, refreshed.second)
            saveTokenExpiry(context, refreshed.third)
        }
    }

    // ---- Local WMS user (no AAD) overlay ----
    /** Saves the locally-authenticated WMS username + resolved profile JSON. The AAD access token
     * still carries the request to BC; this overlay just tells the app which local persona to
     * display / filter for in the UI. */
    fun saveLocalUser(context: Context, username: String, profileJson: String) {
        prefs(context).edit()
            .putString(KEY_LOCAL_USER, username)
            .putString(KEY_LOCAL_PROFILE, profileJson)
            .putBoolean(KEY_ADMIN_TEST_SESSION, false)
            .apply()
    }
    fun getLocalUser(context: Context): String = prefs(context).getString(KEY_LOCAL_USER, "") ?: ""
    fun getLocalProfileJson(context: Context): String = prefs(context).getString(KEY_LOCAL_PROFILE, "") ?: ""
    fun hasLocalUser(context: Context): Boolean = getLocalUser(context).isNotBlank()

    /** Ana sayfadaki karşılama için teknik kullanıcı kodu yerine görünen adı döndürür. */
    fun getOperatorDisplayName(context: Context): String {
        val profile = getLocalProfileJson(context)
        val displayName = runCatching {
            JSONObject(profile.replace("{,", "{")).optString("displayName").trim()
        }.getOrDefault("")
        if (displayName.isNotBlank()) return displayName
        val localUser = getLocalUser(context).trim()
        if (localUser.isNotBlank()) return localUser
        return if (isAdminTestSession(context)) "Yönetici" else ""
    }
    fun clearLocalUser(context: Context) {
        prefs(context).edit()
            .remove(KEY_LOCAL_USER)
            .remove(KEY_LOCAL_PROFILE)
            .putBoolean(KEY_ADMIN_TEST_SESSION, false)
            .apply()
    }

    /** BADE/Dynops saha testi için servis oturumunu açar. Bu bayrak yalnız uygulama içindeki
     * belge sahipliği kapısını aşar; BC isteği yine kurulu servis token'ı ve BC yetkileriyle
     * doğrulanır. Normal WMS kullanıcı girişi veya çıkış bu bayrağı otomatik kapatır. */
    fun startAdminTestSession(context: Context) {
        prefs(context).edit()
            .remove(KEY_LOCAL_USER)
            .remove(KEY_LOCAL_PROFILE)
            .putBoolean(KEY_ADMIN_TEST_SESSION, true)
            .apply()
    }

    fun isAdminTestSession(context: Context): Boolean =
        prefs(context).getBoolean(KEY_ADMIN_TEST_SESSION, false)

    /**
     * Effective operator identity for "assigned to me" filters: the local WMS username when the
     * operator signed in with a WMS account, otherwise the BC User ID of the AAD token — resolved
     * once via appUserProfiles resolveCurrent and cached until sign-out. BC's "Assigned User ID"
     * fields hold exactly this value, so list filters compare against it. Returns "" when BC is
     * unreachable; callers should then fall back to an unfiltered list.
     */
    suspend fun currentUserId(context: Context): String {
        val local = getLocalUser(context)
        if (local.isNotBlank()) return local
        val cached = prefs(context).getString(KEY_BC_USER, "") ?: ""
        if (cached.isNotBlank()) return cached
        val r = boundAction(context, "appUserProfiles", "DEFAULT", "resolveCurrent")
        if (!r.ok) return ""
        val userId = try { JSONObject(scalarValue(r.body)).optString("userId") } catch (e: Exception) { "" }
        if (userId.isNotBlank()) prefs(context).edit().putString(KEY_BC_USER, userId).apply()
        return userId
    }

    // ---- HTTP ----
    data class ApiResult(val ok: Boolean, val httpCode: Int, val body: String)

    data class CountCapabilities(
        val metadataLoaded: Boolean,
        val unexpectedItemAction: Boolean,
        val unexpectedLpAction: Boolean,
        val explicitZeroCount: Boolean,
        val v2PrepareAction: Boolean,
        val v2ScanAction: Boolean,
        val v2UndoAction: Boolean,
        val httpCode: Int,
    ) {
        val varianceReady: Boolean
            get() = metadataLoaded && unexpectedItemAction && unexpectedLpAction && explicitZeroCount
        val v2Ready: Boolean
            get() = metadataLoaded && v2PrepareAction && v2ScanAction && v2UndoAction
    }

    /** Read-only metadata probe used to prevent a newer APK from calling count actions that the
     * currently published AL extension does not yet expose. */
    suspend fun getCountCapabilities(context: Context): CountCapabilities {
        val result = get(context, customApiMetadataUrl(context))
        if (!result.ok)
            return CountCapabilities(false, false, false, false, false, false, false, result.httpCode)
        return parseCountCapabilities(result.body, result.httpCode)
    }

    internal fun parseCountCapabilities(metadata: String, httpCode: Int = 200): CountCapabilities {
        return CountCapabilities(
            metadataLoaded = true,
            unexpectedItemAction = metadata.contains("addUnexpectedItem", ignoreCase = true),
            unexpectedLpAction = metadata.contains("addUnexpectedLp", ignoreCase = true),
            explicitZeroCount = metadata.contains("counted1", ignoreCase = true) &&
                metadata.contains("counted2", ignoreCase = true) &&
                metadata.contains("counted3", ignoreCase = true),
            v2PrepareAction = metadata.contains("prepareV2", ignoreCase = true),
            v2ScanAction = metadata.contains("scanV2Label", ignoreCase = true),
            v2UndoAction = metadata.contains("undoV2Scan", ignoreCase = true),
            httpCode = httpCode,
        )
    }

    suspend fun get(context: Context, path: String): ApiResult = request(context, "GET", path, null)

    /**
     * Reads every OData page for a document collection. A fixed `$top` response
     * is not proof that the document is complete: Business Central returns an
     * `@odata.nextLink` when more rows exist. Mutating/posting screens use the
     * [complete] flag to fail closed after a page or payload error.
     */
    data class PagedItemsResult(
        val rows: List<JSONObject>,
        val complete: Boolean,
        val error: ApiResult? = null,
    )

    internal fun odataNextLink(body: String): String? = runCatching {
        JSONObject(body).optString("@odata.nextLink").trim().takeIf { it.isNotBlank() }
    }.getOrNull()

    suspend fun getAllPages(
        context: Context,
        path: String,
        maxPages: Int = 100,
    ): PagedItemsResult {
        val rows = mutableListOf<JSONObject>()
        val visited = mutableSetOf<String>()
        var next = path
        repeat(maxPages.coerceAtLeast(1)) {
            if (!visited.add(next)) {
                return PagedItemsResult(rows, complete = false, error = ApiResult(false, -1, "Tekrarlanan sayfa bağlantısı"))
            }
            val response = get(context, next)
            if (!response.ok) return PagedItemsResult(rows, complete = false, error = response)
            val page = runCatching {
                val array = JSONObject(response.body).getJSONArray("value")
                (0 until array.length()).map { array.getJSONObject(it) }
            }.getOrElse {
                return PagedItemsResult(rows, complete = false, error = ApiResult(false, -1, "Geçersiz sayfa yanıtı"))
            }
            rows += page
            next = odataNextLink(response.body)
                ?: return PagedItemsResult(rows, complete = true)
        }
        return PagedItemsResult(rows, complete = false, error = ApiResult(false, -1, "Sayfa sınırı aşıldı"))
    }

    /** Custom API first, then the standard API only when the custom collection
     * does not exist. Both branches still follow every server nextLink. */
    suspend fun getAllPagesWithStandardFallback(
        context: Context,
        path: String,
        maxPages: Int = 100,
    ): PagedItemsResult {
        val custom = getAllPages(context, path, maxPages)
        if (custom.error?.httpCode != 404 || custom.rows.isNotEmpty()) return custom
        return getAllPages(context, "${standardApiBase(context)}/$path", maxPages)
    }

    suspend fun getWithStandardFallback(context: Context, path: String): ApiResult {
        val custom = get(context, path)
        if (custom.httpCode != 404) return custom
        return request(context, "GET", "${standardApiBase(context)}/$path", null)
    }

    suspend fun getWithStandardFallback(context: Context, customPath: String, standardPath: String): ApiResult {
        val custom = get(context, customPath)
        if (custom.httpCode != 404) return custom
        return request(context, "GET", "${standardApiBase(context)}/$standardPath", null)
    }

    suspend fun post(context: Context, path: String, jsonBody: String?): ApiResult =
        request(context, "POST", path, jsonBody)

    suspend fun patch(context: Context, path: String, jsonBody: String): ApiResult =
        request(context, "PATCH", path, jsonBody)

    /**
     * Warehouse Pick satırları doğrudan PATCH edilmez. Bu action yerel WMS
     * kullanıcısını sunucuya taşır; BC sahiplik ve lot kontrollerini atomik
     * uygular. Geçici deadlock/throttle yanıtları kısa aralıklarla ve en fazla
     * üç kez denenir; kalıcı doğrulama hataları hiçbir zaman tekrarlanmaz.
     */
    suspend fun confirmPickLine(
        context: Context,
        pickNo: String,
        lineNo: Int,
        qtyToHandle: Double,
        lotNo: String = "",
    ): ApiResult {
        val userId = currentUserId(context)
        if (userId.isBlank()) {
            return ApiResult(
                ok = false,
                httpCode = HttpURLConnection.HTTP_UNAUTHORIZED,
                body = """{"error":{"message":"Depo kullanıcısı belirlenemedi. Yeniden giriş yapın."}}""",
            )
        }
        val body = JSONObject().apply {
            put("lineNo", lineNo)
            put("qtyToHandle", qtyToHandle)
            put("lotNo", lotNo)
            put("userId", userId)
        }.toString()
        var result = boundAction(context, "picks", pickNo, "confirmLine", body)
        repeat(2) { attempt ->
            if (result.ok || !isRetryablePickConfirmation(result.httpCode, result.body)) return result
            delay(if (attempt == 0) 200L else 500L)
            result = boundAction(context, "picks", pickNo, "confirmLine", body)
        }
        return result
    }

    /**
     * Toplama belgesini paylaşılan BC oturumu adına değil, terminalde oturum
     * açmış depo kullanıcısı adına kaydeder. Sunucu bu kimliği mevcut belge
     * sahibiyle atomik olarak karşılaştırır; kullanıcı çözülemezse işlem hiç
     * gönderilmez. Kayıt/post işlemi uzun sürebildiği için uzun zaman aşımlı
     * istemci kullanılır, belirsiz yanıtta ikinci kez post edilmez.
     */
    suspend fun registerPick(context: Context, pickNo: String): ApiResult {
        val userId = currentUserId(context)
        if (userId.isBlank()) {
            return ApiResult(
                ok = false,
                httpCode = HttpURLConnection.HTTP_UNAUTHORIZED,
                body = """{"error":{"message":"Depo kullanıcısı belirlenemedi. Yeniden giriş yapın."}}""",
            )
        }
        val body = JSONObject().apply { put("userId", userId) }.toString()
        return boundActionLongRunning(context, "picks", pickNo, "registerFor", body)
    }

    internal fun isRetryablePickConfirmation(httpCode: Int, body: String): Boolean =
        httpCode == 409 || httpCode == 423 || httpCode == 429 || httpCode >= 500 ||
            body.contains("deadlock", ignoreCase = true) ||
            body.contains("try again", ignoreCase = true)

    suspend fun delete(context: Context, path: String): ApiResult =
        request(context, "DELETE", path, null)

    /**
     * Bound action: POST .../{entitySet}({key})/Microsoft.NAV.{action}
     * BC custom-API string keys MUST be single-quoted, e.g. licensePlates('LP000001').
     * Multi-segment keys (composite) may be passed already-formatted; we only quote when
     * the key is not already wrapped in parentheses-style segments.
     */
    suspend fun boundAction(
        context: Context,
        entitySet: String,
        key: String,
        action: String,
        body: String = "{}"
    ): ApiResult {
        val keySegment = if (key.contains("=") || key.startsWith("'")) key else "'${key.replace("'", "''")}'"
        val path = "$entitySet($keySegment)/Microsoft.NAV.$action"
        return request(context, "POST", path, body)
    }

    /**
     * Sevk/fatura/post gibi BC tarafında birden fazla kayıt oluşturan işlemler
     * normal okutma timeout'uyla kesilmez. Aynı endpoint ve idempotent anahtarlar
     * kullanılır; yalnız bekleme penceresi uzundur.
     */
    suspend fun boundActionLongRunning(
        context: Context,
        entitySet: String,
        key: String,
        action: String,
        body: String = "{}"
    ): ApiResult {
        val keySegment = if (key.contains("=") || key.startsWith("'")) key else "'${key.replace("'", "''")}'"
        val path = "$entitySet($keySegment)/Microsoft.NAV.$action"
        return request(context, "POST", path, body, longRunningClient)
    }

    private val httpClient: OkHttpClient by lazy {
        OkHttpClient.Builder()
            // Depo hızı: kopuk/zayıf bağlantıda operatör 20 sn beklemesin.
            // BC normalde <1 sn yanıtlar; bu değerler "gerçekten sorun var"ı
            // hızla ortaya çıkarır, kullanıcı erken hata görüp tekrar dener.
            .connectTimeout(8, TimeUnit.SECONDS)
            .readTimeout(12, TimeUnit.SECONDS)
            .writeTimeout(12, TimeUnit.SECONDS)
            // Depoda her okutma bir HTTP çağrısı: TLS el sıkışmasını her seferinde
            // tekrarlamamak için bağlantıları uzun süre havuzda tut (aksi halde
            // her scan'de ~300-600 ms sadece handshake'e gidiyor).
            .connectionPool(okhttp3.ConnectionPool(12, 10, TimeUnit.MINUTES))
            .retryOnConnectionFailure(true)
            // Şirket keşfi gibi paralel yoklamalarda host başına eşzamanlılık
            // varsayılan 5'te sıkışmasın.
            .dispatcher(okhttp3.Dispatcher().apply {
                maxRequests = 32
                maxRequestsPerHost = 16
            })
            .build()
    }

    private val longRunningClient: OkHttpClient by lazy {
        httpClient.newBuilder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(90, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .callTimeout(120, TimeUnit.SECONDS)
            .build()
    }

    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    private suspend fun request(
        context: Context,
        method: String,
        path: String,
        jsonBody: String?,
        client: OkHttpClient = httpClient,
    ): ApiResult =
        withContext(Dispatchers.IO) {
            ensureFreshToken(context)
            val token = getToken(context)
            if (token.isBlank()) return@withContext ApiResult(false, 0, "Token yok — Bağlantı Ayarları ekranından token girin")
            try {
                val rawUrl = if (path.startsWith("http")) path else "${customApiBase(context)}/$path"
                val url = rawUrl.replace(" ", "%20").replace("'", "%27")
                // OkHttp sends real PATCH/DELETE verbs. Android's HttpURLConnection cannot do PATCH, and
                // BC's API endpoint ignores the X-HTTP-Method-Override fallback → POST-tunneled PATCH lands
                // as a literal POST to a keyed entity and is rejected with HTTP 405 on line updates.
                val requestBody = when {
                    jsonBody != null -> jsonBody.toRequestBody(jsonMediaType)
                    // OkHttp requires a (possibly empty) body for POST/PATCH/PUT.
                    method == "POST" || method == "PATCH" || method == "PUT" -> ByteArray(0).toRequestBody(jsonMediaType)
                    else -> null
                }
                val builder = Request.Builder()
                    .url(url)
                    .method(method, requestBody)
                    .header("Authorization", "Bearer $token")
                    .header("Accept", "application/json")
                // Manual/automatic refresh must reach BC. Some customer
                // proxies cache identical OData GETs and made the Yenile
                // button appear to do nothing after a warehouse transaction.
                if (method == "GET") {
                    builder.header("Cache-Control", "no-cache, no-store")
                    builder.header("Pragma", "no-cache")
                }
                // BC requires If-Match for PATCH/DELETE; "*" skips optimistic-concurrency check.
                if (method == "PATCH" || method == "DELETE") builder.header("If-Match", "*")
                client.newCall(builder.build()).execute().use { resp ->
                    val code = resp.code
                    val body = resp.body?.string().let { if (it.isNullOrEmpty()) "(no body)" else it }
                    if (code != 401) return@use ApiResult(code in 200..299, code, body)
                    // Access token expired (~1h). Try a silent refresh once, then replay the request,
                    // so the operator is not silently logged out mid-shift.
                    val refreshed = synchronized(this@BcApi) {
                        val rt = getRefreshToken(context)
                        if (rt.isBlank()) null else DeviceAuth.refreshAccessToken(rt, getTenant(context))
                    } ?: return@use ApiResult(false, code, body)
                    saveToken(context, refreshed.first)
                    saveRefreshToken(context, refreshed.second)
                    saveTokenExpiry(context, refreshed.third)
                    val retry = builder.header("Authorization", "Bearer ${refreshed.first}").build()
                    client.newCall(retry).execute().use { r2 ->
                        val b2 = r2.body?.string().let { if (it.isNullOrEmpty()) "(no body)" else it }
                        ApiResult(r2.code in 200..299, r2.code, b2)
                    }
                }
            } catch (e: Exception) {
                ApiResult(false, -1, "Hata: ${e.message}")
            }
        }

    // ---- Connection test ----
    /**
     * Şirket bağlantısını tek bir operasyonel veri kümesine bağlama. LP tablosundaki
     * bozuk/eski bir kayıt veya LP'ye özel filtre hatası, WMS API'si ve şirket erişimi
     * sağlam olsa bile giriş ekranını kapatabiliyordu. Yerel kullanıcı API'si giriş
     * akışının gerçekten ihtiyaç duyduğu en hafif probdur; eski BC paketleri için LP
     * sorgusu yedek olarak korunur.
     */
    suspend fun testConnection(context: Context): ApiResult {
        var result = ApiResult(false, -1, "Bağlantı henüz denenmedi")
        repeat(4) { attempt ->
            val localUsers = get(context, "localUsers?\$top=1&\$select=username")
            if (localUsers.ok) return localUsers
            val licensePlates = get(context, "licensePlates?\$top=1&\$select=no")
            result = selectConnectionProbeResult(localUsers, licensePlates)
            if (!isRetryableConnectionFailure(result) || attempt == 3) return result

            // Extension publish/upgrade sonrasında BC'nin OData rotaları birkaç
            // saniye 404/5xx dönebiliyor. Operatöre yanlış bir ilk-hata göstermeden
            // kısa artan aralıklarla aynı şirketi yeniden doğrula.
            delay(listOf(250L, 650L, 1_200L)[attempt])
        }
        return result
    }

    internal fun selectConnectionProbeResult(primary: ApiResult, fallback: ApiResult): ApiResult =
        when {
            primary.ok -> primary
            fallback.ok -> fallback
            primary.httpCode !in listOf(404, 405) -> primary
            else -> fallback
        }

    internal fun isRetryableConnectionFailure(result: ApiResult): Boolean =
        result.httpCode == -1 ||
            result.httpCode == 404 ||
            result.httpCode == 408 ||
            result.httpCode == 425 ||
            result.httpCode == 429 ||
            result.httpCode >= 500

    /** True when a mutating request may have reached BC despite the failed response. */
    internal fun isAmbiguousMutationFailure(result: ApiResult): Boolean =
        result.httpCode == -1 ||
            result.httpCode == 408 ||
            result.httpCode == 425 ||
            result.httpCode == 429 ||
            result.httpCode >= 500

    fun connectionFailureMessage(result: ApiResult): String = when (result.httpCode) {
        0, -1 -> "BC sunucusuna ulaşılamadı. İnternet bağlantısını kontrol edip tekrar deneyin."
        401 -> "BC oturumunun süresi dolmuş. E-posta ile yeniden giriş yapın."
        403 -> "Bu kullanıcıya seçilen şirkette WMS API yetkisi verilmemiş. BC yetkilerini kontrol edin."
        404, 405 -> "WMS BC paketi bu ortamda erişilebilir değil. Doğru ortama güncel paketi yükleyin."
        else -> "Şirket bağlantısı doğrulanamadı (kod ${result.httpCode}). Tekrar deneyin."
    }

    /** Bound actions that return Edm.String wrap the result as {"value":"..."}; extract it. */
    fun scalarValue(body: String): String =
        try { JSONObject(body).optString("value") } catch (e: Exception) { "" }

    /** Pull a human-readable message out of a BC error body (or fall back to raw). */
    fun errorMessage(body: String): String =
        try {
            JSONObject(body).getJSONObject("error").optString("message").ifBlank { body }
        } catch (e: Exception) {
            body.take(300)
        }

    // ---- Helper: JSON value array parse ----
    fun parseValueArray(body: String): List<JSONObject> {
        return try {
            val arr = JSONObject(body).getJSONArray("value")
            (0 until arr.length()).map { arr.getJSONObject(it) }
        } catch (e: Exception) {
            emptyList()
        }
    }

    // ---- Environment / company discovery (after email sign-in) ----
    data class Company(val id: String, val name: String, val displayName: String)
    data class EnvCompanies(val environment: String, val companies: List<Company>)

    /**
     * Token'ın tenant'ında bilinen ortamları yoklar; şirket dönenleri listeler.
     * Multi-tenant: tenant token'dan (tid) çözülür — BADE token'ıyla BADE
     * tenant'ı, DynamicsOps token'ıyla DynamicsOps tenant'ı sorgulanır.
     */
    suspend fun discoverEnvironments(token: String): List<EnvCompanies> = withContext(Dispatchers.IO) {
        val tenant = tenantIdFromJwt(token) ?: FALLBACK_TENANT
        KNOWN_ENVIRONMENTS.mapNotNull { env -> probeEnvironment(tenant, env, token) }
    }

    /** Tek bir ortamı yoklar; şirket dönerse EnvCompanies, yoksa null.
     *  Otomatik keşif ortamı bulamazsa kullanıcının elle girdiği ortam adı için. */
    suspend fun probeEnvironment(tenant: String, env: String, token: String): EnvCompanies? = withContext(Dispatchers.IO) {
        val cleanEnv = env.trim()
        if (!BuildConfig.BC_ALLOW_PRODUCTION && cleanEnv.equals("Production", ignoreCase = true)) {
            return@withContext null
        }
        val r = httpGet(companiesUrl(tenant, cleanEnv), token)
        if (!r.ok) return@withContext null
        val companies = parseValueArray(r.body).map {
            Company(it.optString("id"), it.optString("name"), it.optString("displayName").ifBlank { it.optString("name") })
        }
        if (companies.isEmpty()) null else EnvCompanies(cleanEnv, companies)
    }

    /** Plain authenticated GET with an explicit token (used by discovery / sign-in verification). */
    suspend fun httpGet(url: String, token: String): ApiResult = withContext(Dispatchers.IO) {
        try {
            val conn = (URL(url.replace(" ", "%20")).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Accept", "application/json")
                connectTimeout = 15000; readTimeout = 20000
            }
            val code = conn.responseCode
            val body = if (code in 200..299) conn.inputStream.bufferedReader().readText()
                else conn.errorStream?.bufferedReader()?.readText() ?: "(no body)"
            ApiResult(code in 200..299, code, body)
        } catch (e: Exception) { ApiResult(false, -1, "Hata: ${e.message}") }
    }
}
