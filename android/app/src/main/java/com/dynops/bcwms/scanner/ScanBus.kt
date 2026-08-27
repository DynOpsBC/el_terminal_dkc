package com.dynops.bcwms.scanner

import android.content.Intent
import android.util.Log
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/**
 * Singleton broadcast hub that bridges Zebra DataWedge intents (and any
 * other "external scanner" source) to the Compose UI. Reported in PDF
 * section 6 (Zebra Barkod Tarayıcı Entegrasyonu) as a SHIP-BLOCKER: the
 * DataWedgeScanner sınıfı zaten var ama ScanField hiç dinlemiyordu.
 *
 * Flow:
 *   1. DataWedge profili `Intent Output` ile bu uygulamaya `com.dynops.bcwms.SCAN`
 *      action'ı + `com.symbol.datawedge.data_string` extra'sı gönderir.
 *   2. `MainActivity.onNewIntent()` intent'i alıp `ScanBus.dispatch(intent)`
 *      ile buraya pipe eder.
 *   3. Aktif ekrandaki `ScanField` `LaunchedEffect` ile `events` flow'una
 *      subscribe olur, ilk barkod gelince `onScanned(raw)` callback'ini
 *      tetikler.
 *
 * `replay = 0` — geç açılan abone önceki taramayı görmesin (üretim ortamında
 * tek tarama bir defa kullanılmalı).
 *
 * `extraBufferCapacity = 4` — peş peşe yapılan tetik basışları (operatör
 * yanlışlıkla iki kez bastı) drop edilmesin diye küçük bir tampon.
 */
object ScanBus {
    private const val TAG = "BcwmsScanBus"

    private val _events = MutableSharedFlow<ScanEvent>(
        replay = 0,
        extraBufferCapacity = 4,
    )
    val events: SharedFlow<ScanEvent> = _events.asSharedFlow()

    /**
     * Called from `MainActivity.onNewIntent`. Parses a DataWedge intent and
     * emits a `ScanEvent`. Safe to call with any intent — irrelevant ones
     * are silently ignored.
     */
    fun dispatch(intent: Intent?) {
        if (intent == null) return
        if (intent.action != ACTION_SCAN) return
        val data = intent.getStringExtra(EXTRA_DATA_STRING).orEmpty()
        if (data.isBlank()) return
        val symbology = intent.getStringExtra(EXTRA_LABEL_TYPE) ?: ""
        Log.d(TAG, "intent → ${data.take(30)} ($symbology)")
        val ok = _events.tryEmit(ScanEvent(raw = data, symbology = symbology))
        if (!ok) Log.w(TAG, "scan dropped (buffer full)")
    }

    /**
     * Direct emit path for unit tests and the existing camera fallback.
     * Camera scans currently call onScanned() locally so they don't go
     * through the bus — only hardware scans do, which is fine.
     */
    fun emit(event: ScanEvent) {
        _events.tryEmit(event)
    }

    // DataWedge intent contract — mirrored from android/core-scanner module
    // so the app module doesn't need to depend on it.
    private const val ACTION_SCAN = "com.dynops.bcwms.SCAN"
    private const val EXTRA_DATA_STRING = "com.symbol.datawedge.data_string"
    private const val EXTRA_LABEL_TYPE = "com.symbol.datawedge.label_type"
}

data class ScanEvent(
    val raw: String,
    val symbology: String,
)
