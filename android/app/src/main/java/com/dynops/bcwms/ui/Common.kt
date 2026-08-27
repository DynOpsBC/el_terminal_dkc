package com.dynops.bcwms.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.json.JSONObject

/** First non-blank API value among the given keys; empty if none. */
fun rawValue(obj: JSONObject, vararg keys: String): String {
    for (key in keys) {
        val value = obj.optString(key)
        if (value.isNotBlank() && value != "null") return value
    }
    return ""
}

/** Display-only variant of [rawValue]; never pass its "-" placeholder to BC. */
fun firstValue(obj: JSONObject, vararg keys: String): String =
    rawValue(obj, *keys).ifBlank { "-" }

@Composable
fun EmptyState(message: String) {
    Card(
        Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Text(
            message,
            Modifier.padding(16.dp),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

/**
 * Operasyon listelerinin ortak belge kartı. Uzun kaynak/lokasyon/kullanıcı
 * bilgilerini telefonda güvenli biçimde iki satıra sınırlar; eski renkli dolgu
 * yerine beyaz zemin ve ince sınır kullanır.
 */
@Composable
fun OperationDocumentCard(
    title: String,
    metadata: String,
    onClick: () -> Unit,
    status: String = "",
    progressPercent: Int? = null,
) {
    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
    ) {
        Column(Modifier.padding(horizontal = 14.dp, vertical = 12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                if (status.isNotBlank()) {
                    Spacer(Modifier.width(8.dp))
                    Surface(
                        color = MaterialTheme.colorScheme.primaryContainer,
                        shape = RoundedCornerShape(50),
                    ) {
                        Text(
                            status,
                            modifier = Modifier.padding(horizontal = 9.dp, vertical = 4.dp),
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            }
            Spacer(Modifier.height(4.dp))
            Text(
                metadata,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            progressPercent?.let { percent ->
                Spacer(Modifier.height(9.dp))
                LinearProgressIndicator(
                    progress = { percent.coerceIn(0, 100) / 100f },
                    modifier = Modifier.fillMaxWidth().height(4.dp).clip(RoundedCornerShape(50)),
                    color = MaterialTheme.colorScheme.primary,
                    trackColor = MaterialTheme.colorScheme.surfaceVariant,
                )
            }
        }
    }
}

/** Status banner that colour-codes PASS / EMPTY / error text. */
@Composable
fun StatusText(status: String) {
    if (status.isBlank()) return
    val visibleStatus = operatorFacingStatus(status)
    val palette = bcwmsStatus()
    val color = when {
        visibleStatus.startsWith("TAMAM") || visibleStatus.startsWith("🟢") || visibleStatus.startsWith("✅") -> palette.success
        visibleStatus.startsWith("BOŞ") || visibleStatus.startsWith("⚠️") -> palette.warning
        visibleStatus.startsWith("HATA") || visibleStatus.startsWith("🔴") || visibleStatus.startsWith("❌") -> palette.danger
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }
    Surface(
        color = color.copy(alpha = 0.10f),
        shape = RoundedCornerShape(10.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(Modifier.padding(horizontal = 11.dp, vertical = 9.dp), verticalAlignment = Alignment.Top) {
            val glyph = if (visibleStatus.startsWith("HATA") || visibleStatus.startsWith("BOŞ") || visibleStatus.startsWith("⚠")) {
                WmsGlyph.WARNING
            } else {
                WmsGlyph.QUALITY
            }
            WmsIcon(glyph, color, Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text(
                visibleStatus,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

/**
 * API ayrıntıları destek kaydında kalır; saha operatörüne yalnız yapılabilir
 * bir sonraki adım gösterilir. Bu dönüşüm yalnız ekrana basılan metne uygulanır,
 * iş akışının hata sınıflandırmasını değiştirmez.
 */
fun operatorFacingStatus(raw: String): String {
    if (raw.isBlank()) return raw
    val englishBcValidation = Regex(
        """\b(required|must|cannot|already|not\s+found|no\s+longer|nothing\s+to|not\s+allowed|unable\s+to|failed\s+to)\b""",
        RegexOption.IGNORE_CASE,
    ).containsMatchIn(raw) ||
        Regex("""\b(Table|Field)\s+[A-Za-z0-9_. -]+""", RegexOption.IGNORE_CASE).containsMatchIn(raw) ||
        raw.contains("No.=", ignoreCase = true)
    val technicalDeployment = raw.contains("publish", ignoreCase = true) ||
        raw.contains("güncel BC", ignoreCase = true) ||
        raw.contains("uzantısını yayın", ignoreCase = true) ||
        raw.contains("CorrelationId", ignoreCase = true) ||
        raw.contains("Identification fields", ignoreCase = true) ||
        raw.contains("Microsoft.", ignoreCase = true) ||
        raw.contains("Exception", ignoreCase = true) ||
        raw.contains("Bad Request", ignoreCase = true) ||
        raw.contains("OData", ignoreCase = true) ||
        raw.contains(" does not ", ignoreCase = true) ||
        raw.contains(" is not ", ignoreCase = true) ||
        englishBcValidation ||
        raw.trimStart().startsWith("{")
    if (technicalDeployment) {
        return operatorFacingApiError(raw)
    }
    return raw
        .replace(Regex("""\s*\(HTTP\s*\d+\)""", RegexOption.IGNORE_CASE), "")
        .replace(Regex("""\bHTTP\s*\d+\b""", RegexOption.IGNORE_CASE), "")
        .replace(Regex("""\breclass\b""", RegexOption.IGNORE_CASE), "stok hareketi")
        .replace(Regex("""\bslot\b""", RegexOption.IGNORE_CASE), "sayıcı")
        .replace(Regex("""\s{2,}"""), " ")
        .trim()
}

/** Stable, non-sensitive reference for matching an operator report to raw logs. */
fun operatorSupportReference(raw: String, httpCode: Int = 0): String =
    "REF-" + "$httpCode:${raw.trim()}".hashCode().toUInt().toString(16).uppercase().padStart(8, '0')

/** Raw BC/transport errors never belong on the warehouse terminal. */
fun operatorFacingApiError(raw: String, httpCode: Int = 0): String {
    val action = when {
        raw.contains("lot", ignoreCase = true) ->
            "Lot bilgisi doğrulanamadı. Yenileyip tekrar deneyin."
        raw.contains("printer", ignoreCase = true) || raw.contains("yazıcı", ignoreCase = true) ->
            "Yazıcı ayarı tamamlanamadı. Yazıcılar ekranını yenileyin."
        raw.contains("quantity", ignoreCase = true) || raw.contains("miktar", ignoreCase = true) ->
            "Miktar kaydedilemedi. Değeri kontrol edip tekrar deneyin."
        else -> "İşlem tamamlanamadı. Yenileyip tekrar deneyin."
    }
    return "HATA: $action Sorun sürerse yöneticinize ${operatorSupportReference(raw, httpCode)} kodunu iletin."
}

/** Non-clickable state badge. AssistChip is intentionally not used. */
@Composable
fun InfoPill(
    text: String,
    containerColor: Color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
    contentColor: Color = MaterialTheme.colorScheme.primary,
) {
    Surface(shape = RoundedCornerShape(50), color = containerColor) {
        Text(
            text,
            Modifier.padding(horizontal = 9.dp, vertical = 5.dp),
            style = MaterialTheme.typography.labelSmall,
            color = contentColor,
        )
    }
}

/** Reusable document header card. */
@Composable
fun DocHeaderCard(title: String, subtitle: String, badge: String? = null, percent: Int? = null) {
    Card(
        Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
    ) {
        Column(Modifier.padding(16.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text(
                    title,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                badge?.let {
                    Spacer(Modifier.width(10.dp))
                    Surface(shape = RoundedCornerShape(50), color = MaterialTheme.colorScheme.primary.copy(alpha = 0.14f)) {
                        Text(
                            it,
                            Modifier.padding(horizontal = 10.dp, vertical = 5.dp),
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary,
                            maxLines = 1,
                        )
                    }
                }
            }
            Spacer(Modifier.height(6.dp))
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            if (percent != null) {
                Spacer(Modifier.height(8.dp))
                LinearProgressIndicator(
                    progress = { (percent.coerceIn(0, 100)) / 100f },
                    modifier = Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(50)),
                )
                Spacer(Modifier.height(4.dp))
                Text("%$percent tamamlandı", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

/** Bottom action bar: a row of buttons pinned under content. */
@Composable
fun BottomActionBar(content: @Composable RowScope.() -> Unit) {
    Surface(tonalElevation = 3.dp, shadowElevation = 8.dp) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
            content = content
        )
    }
}
