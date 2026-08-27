package com.dynops.bcwms

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.material3.Surface
import androidx.compose.runtime.LaunchedEffect
import com.dynops.bcwms.scanner.ScanBus
import com.dynops.bcwms.ui.BcwmsTheme

class MainActivity : ComponentActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    enableEdgeToEdge()
    // Codex review Finding 7: cold-start'ta ScanBus.dispatch'i doğrudan
    // burada çağırırsak hiç bir ScanField henüz collect etmediğinden
    // SharedFlow(replay=0, extraBufferCapacity=4) emit'i drop edebilir.
    // setContent içinden LaunchedEffect(Unit) ile dispatch, Compose tree
    // mount edildikten sonra çalışır → subscriber'lar hazır → drop yok.
    val coldStartIntent: Intent? = intent
    setContent {
      LaunchedEffect(Unit) { ScanBus.dispatch(coldStartIntent) }
      BcwmsTheme {
        Surface {
          AppRoot()
        }
      }
    }
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    // Warm intent: app zaten foreground'da, Zebra sarı tetik tarayan
    // operatörün barkodunu ScanBus üzerinden aktif ekrana ulaştır.
    ScanBus.dispatch(intent)
  }
}
