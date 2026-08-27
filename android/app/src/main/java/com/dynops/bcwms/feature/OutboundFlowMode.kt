package com.dynops.bcwms.feature

import androidx.compose.ui.graphics.Color

/**
 * V2'nin kullanıcıya görünen üç outbound operasyonu. BC'deki Bulk/Batch
 * enum adları geriye dönük uyumluluk için kaldığından eşleme burada tek yerde.
 */
enum class OutboundFlowMode(
    val apiValue: String,
    val title: String,
    val subtitle: String,
    val icon: String,
    val accent: Color,
) {
    Multi(
        apiValue = "Multi",
        title = "Multi",
        subtitle = "Çok sipariş · çok ürün",
        icon = "▦",
        accent = Color(0xFF6C5CE7),
    ),
    Mono(
        apiValue = "Batch",
        title = "Mono",
        subtitle = "Her siparişte farklı tek ürün",
        icon = "1×",
        accent = Color(0xFF168C72),
    ),
    SingleSku(
        apiValue = "Bulk",
        title = "Tek SKU",
        subtitle = "Çok sipariş · aynı ürün",
        icon = "≡",
        accent = Color(0xFFE07A2D),
    );

    companion object {
        fun fromApi(value: String): OutboundFlowMode? = entries.firstOrNull {
            it.apiValue.equals(value.trim(), ignoreCase = true) ||
                it.title.equals(value.trim(), ignoreCase = true)
        }
    }
}
