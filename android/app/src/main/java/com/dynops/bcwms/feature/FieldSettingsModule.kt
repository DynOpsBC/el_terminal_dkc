package com.dynops.bcwms.feature

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dynops.bcwms.ui.*
import org.json.JSONObject

/**
 * Alan Ayarları — Warehouse Insight'ın "kolon seçimi" ekranının karşılığı.
 * Kullanıcı, satır kartlarında hangi ek alanların görüneceğini açıp kapatır.
 * Tercihler cihazda kalıcıdır ve tüm görev ekranlarına anında yansır.
 */
@Composable
fun FieldSettingsModule() {
    val context = LocalContext.current
    LaunchedEffect(Unit) { FieldPrefs.load(context) }

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        Text("Görünen Satır Alanları", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Spacer(Modifier.height(4.dp))
        Text(
            "Ürün no + isim benzer ürünlerde yetmiyor. Satır kartlarında ek olarak hangi " +
                "alanların görüneceğini buradan seçin. Her cihaz/kullanıcı kendine göre ayarlar.",
            fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(16.dp))

        FieldPrefs.fields.forEach { f ->
            Card(Modifier.fillMaxWidth().padding(vertical = 4.dp), shape = MaterialTheme.shapes.medium) {
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(f.label, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
                        Text(f.hint, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Switch(
                        checked = FieldPrefs.isOn(f.key),
                        onCheckedChange = { FieldPrefs.set(context, f.key, it) },
                    )
                }
            }
        }

        Spacer(Modifier.height(20.dp))
        Text("Önizleme", fontWeight = FontWeight.SemiBold, fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(8.dp))
        PreviewLineCard()

        Spacer(Modifier.height(20.dp))
        Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
            Text(
                "Not: Bu ayar cihaza özeldir ve tüm ekranlarda ortaktır. Firma-geneli merkezi " +
                    "yönetim ve ekran-bazlı ayrı kolon seçimi sonraki fazda gelecek.",
                Modifier.padding(12.dp), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Spacer(Modifier.height(16.dp))
    }
}

/** Seçili alanların satır kartında nasıl görüneceğini gösteren canlı örnek. */
@Composable
private fun PreviewLineCard() {
    // Örnek bir satır — açık olan alanlar burada anında görünür/kaybolur.
    val sample = remember {
        JSONObject().apply {
            put("itemNo", "1000-S")
            put("description", "Biberiye Suyu 500ml")
            put("unitOfMeasureCode", "KOLI")
            put("variantCode", "RED")
            put("itemReference", "8690123459848")
            put("description2", "Guangzhou / standing")
        }
    }
    Card(Modifier.fillMaxWidth(), colors = doneCardColors(true)) {
        Column(Modifier.padding(14.dp)) {
            Text("✓ ${sample.optString("itemNo")} — ${sample.optString("description")}", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
            Text("Kalan: 40 · Alınan: 0", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            val extra = extraFieldsText(sample)
            if (extra.isNotBlank()) Text(extra, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
