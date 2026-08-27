package com.dynops.bcwms.feature

internal fun receivingPreflightFailureStatus(resetCount: Int): String =
    if (resetCount > 0) {
        "UYARI: $resetCount satır sıfırlandı, kalan satırlar işlenemedi. Belge yenilendi; mal kabul kaydedilmedi."
    } else {
        "HATA: İşlenmeyen satırlar güvenle ayrıştırılamadı. Belge yenilendi; mal kabul kaydedilmedi."
    }
