package com.dynops.bcwms.scanner

/**
 * Classifies a scanned barcode string into a warehouse intent.
 *
 * Mirrors the 5 default barcode rules from the AdvWMS spec:
 *   1. EAN-13 (13 digits)            -> Item
 *   2. GS1-128 (FNC / AI prefixes)   -> Item (+ optional Lot / Expiry / Serial parsed from AIs)
 *   3. SSCC-18 (18 digits, AI 00)    -> License Plate
 *   4. B-* prefix                    -> Bin
 *   5. TPL-* prefix                  -> LP Template
 *
 * A document screen declares which [BarcodeKind]s it accepts; [resolve] returns a
 * [ResolvedBarcode] the screen can accept or reject.
 */
enum class BarcodeKind { Item, Bin, Lp, LpTemplate, Lot, Serial, Document, Unknown }

data class ResolvedBarcode(
    val kind: BarcodeKind,
    /** Primary value (item no, bin code, LP no, template code, ...). */
    val value: String,
    /** Raw scanned text. */
    val raw: String,
    /** Extra fields parsed from GS1-128 application identifiers. */
    val itemNo: String? = null,
    val lotNo: String? = null,
    val serialNo: String? = null,
    val expiry: String? = null,
    /** Etikette açıkça yazan varyant ve ölçü birimi; yoksa sunucu ürün kartından tamamlar. */
    val variantCode: String? = null,
    val unitOfMeasureCode: String? = null,
    /** Belge barkoduysa belge türü: receipt/shipment/putaway/pick/movement/salesOrder/purchaseOrder/... */
    val docType: String? = null,
    /** Etiketin üzerindeki miktar (GS1 AI 30/37 veya alan adlı firma QR'ı). */
    val quantity: Double? = null,
)

object BarcodeIntentResolver {

    fun resolve(raw0: String): ResolvedBarcode {
        val raw = raw0.trim()
        if (raw.isEmpty()) return ResolvedBarcode(BarcodeKind.Unknown, "", raw)

        // Rule 4 & 5: explicit prefixes
        when {
            raw.startsWith("B-", ignoreCase = true) ->
                return ResolvedBarcode(BarcodeKind.Bin, raw, raw)
            raw.startsWith("TPL-", ignoreCase = true) ->
                return ResolvedBarcode(BarcodeKind.LpTemplate, raw, raw)
            raw.startsWith("LP", ignoreCase = true) && raw.drop(2).all { it.isDigit() } && raw.length >= 4 ->
                return ResolvedBarcode(BarcodeKind.Lp, raw, raw)
        }

        // Belge barkodları (Warehouse Insight %X% kodları + düz BC belge no'ları) → belgeyi aç.
        resolveDocument(raw)?.let { return it }

        // Rule 2: GS1-128 — contains application identifiers like (01), (10), (17), (21) or FNC1 group separators
        if (looksLikeGs1(raw)) {
            return parseGs1(raw)
        }

        // Müşteri madde tanımlama etiketleri GS1 yerine okunabilir alan adları
        // taşıyabilir. Örnek:
        //   MADDE KODU=AB.00005; LOT NO=A100797; MİKTAR/BİRİM=5,000 ADET
        // JSON ve URL query biçimleri de aynı anahtarlarla bu kurala girer.
        parseCustomItemLabel(raw)?.let { return it }

        // Rule 3: SSCC-18 — 18 digits, often prefixed by AI 00 (20 digits with the prefix)
        if (raw.all { it.isDigit() } && raw.length == 18) {
            return ResolvedBarcode(BarcodeKind.Lp, raw, raw)
        }
        if (raw.all { it.isDigit() } && raw.length == 20 && raw.startsWith("00")) {
            return ResolvedBarcode(BarcodeKind.Lp, raw.drop(2), raw)
        }

        // Rule 1: EAN-13 / pure numeric -> item
        if (raw.all { it.isDigit() } && (raw.length == 13 || raw.length == 12 || raw.length == 8)) {
            return ResolvedBarcode(BarcodeKind.Item, raw, raw, itemNo = raw)
        }

        // Default: treat as item code (alphanumeric item no like "1896-S")
        return ResolvedBarcode(BarcodeKind.Item, raw, raw, itemNo = raw)
    }

    /**
     * Belge barkodu mu? İki format tanınır:
     *  - Warehouse Insight sarmalayıcısı: %R%RE000035, %WS%SH..., %A%PU00001 (aktivite), %S%/%PO%/%T%/%AO%/%P%
     *  - Düz BC belge no'su: RE.../SH.../PU.../PI.../WM... + rakam
     * Kaynak belgeler (SO/PO numeric) yalnız %S%/%PO% ile tanınır; düz sayı üründen ayırt edilemez.
     */
    private fun resolveDocument(raw: String): ResolvedBarcode? {
        val wrapped = Regex("^%([A-Za-z]+)%(\\S+)").find(raw)
        if (wrapped != null) {
            val tag = wrapped.groupValues[1].uppercase()
            val no = wrapped.groupValues[2].trim()
            val type = when (tag) {
                "R" -> "receipt"
                "WS" -> "shipment"
                "S" -> "salesOrder"
                "PO" -> "purchaseOrder"
                "T" -> "transferOrder"
                "AO" -> "assembly"
                "P" -> "production"
                "A" -> docTypeFromPrefix(no)   // Whse Activity: türü gömülü no'nun ön ekinden çöz
                else -> null
            }
            if (type != null) return ResolvedBarcode(BarcodeKind.Document, no, raw, docType = type)
        }
        docTypeFromPrefix(raw)?.let { return ResolvedBarcode(BarcodeKind.Document, raw.trim(), raw, docType = it) }
        return null
    }

    /** RE.../SH.../PU.../PI.../WM... + rakam → belge türü; aksi halde null. */
    private fun docTypeFromPrefix(s: String): String? {
        val v = s.trim().uppercase()
        return when {
            Regex("^RE\\d{3,}$").matches(v) -> "receipt"
            Regex("^SH\\d{3,}$").matches(v) -> "shipment"
            Regex("^PU\\d{3,}$").matches(v) -> "putaway"
            Regex("^PI\\d{3,}$").matches(v) -> "pick"
            Regex("^WM\\d{3,}$").matches(v) -> "movement"
            else -> null
        }
    }

    private fun looksLikeGs1(raw: String): Boolean {
        if (raw.contains("(01)") || raw.contains("(02)") || raw.contains("(10)") || raw.contains("(17)") ||
            raw.contains("(21)") || raw.contains("(00)") || raw.contains("(30)") || raw.contains("(37)")
        ) return true
        // FNC1 group separator (GS, ASCII 29) present
        if (raw.contains('\u001D')) return true
        return false
    }

    /** Parse a subset of GS1 AIs: 00=SSCC, 01=GTIN(item), 10=lot, 17=expiry, 21=serial, 30/37=miktar. */
    private fun parseGs1(raw: String): ResolvedBarcode {
        // Normalise both parenthesised "(01)..." and FNC1-delimited forms.
        val ais = mutableMapOf<String, String>()
        val gs = '\u001D'
        if (raw.contains('(')) {
            val regex = Regex("\\((\\d{2,4})\\)([^()]*)")
            for (m in regex.findAll(raw)) ais[m.groupValues[1]] = m.groupValues[2].trim()
        } else {
            // Best-effort fixed-length parse for common AIs in FNC1 streams.
            var rest = raw
            val fixed = mapOf("00" to 18, "01" to 14, "02" to 14, "17" to 6)
            while (rest.length >= 2) {
                val ai = rest.take(2)
                when {
                    fixed.containsKey(ai) -> {
                        val len = fixed[ai]!!
                        ais[ai] = rest.drop(2).take(len)
                        // Sabit uzunluklu AI'dan sonra da FNC1 (GS) gelebilir; yutulmazsa
                        // bir sonraki AI '\u001D3' gibi okunur ve kalan parse kopar.
                        rest = rest.drop(2 + len).removePrefix(gs.toString())
                    }
                    ai == "10" || ai == "21" || ai == "30" || ai == "37" -> {
                        val seg = rest.drop(2).substringBefore(gs)
                        ais[ai] = seg
                        rest = rest.drop(2 + seg.length).removePrefix(gs.toString())
                    }
                    else -> break
                }
            }
        }

        val sscc = ais["00"]
        val gtin = ais["01"] ?: ais["02"]
        val lot = ais["10"]?.ifBlank { null }
        val expiry = ais["17"]?.ifBlank { null }
        val serial = ais["21"]?.ifBlank { null }
        // AI 30 (variable count) / AI 37 (count of trade items) — etiketteki adet.
        val qty = (ais["30"] ?: ais["37"])?.trim()?.takeIf { it.isNotEmpty() }?.toDoubleOrNull()

        return when {
            sscc != null -> ResolvedBarcode(BarcodeKind.Lp, sscc, raw, lotNo = lot, serialNo = serial, expiry = expiry, quantity = qty)
            gtin != null -> ResolvedBarcode(BarcodeKind.Item, gtin, raw, itemNo = gtin, lotNo = lot, serialNo = serial, expiry = expiry, quantity = qty)
            else -> ResolvedBarcode(BarcodeKind.Unknown, raw, raw, lotNo = lot, serialNo = serial, expiry = expiry, quantity = qty)
        }
    }

    /**
     * Firma etiketlerindeki alan adlarını okur. Fotoğrafta görünen basılı değer
     * değil, QR'ın ham içeriği ayrıştırılır; bu yüzden yalnız açıkça adlandırılmış
     * alanlar kabul edilir ve serbest metinden yanlış miktar tahmini yapılmaz.
     */
    private fun parseCustomItemLabel(raw: String): ResolvedBarcode? {
        val itemNo = CUSTOM_ITEM.find(raw)?.groupValues?.get(1)?.trim()?.trim('"', '\'')
            ?.takeIf { it.isNotBlank() }
        val lotNo = CUSTOM_LOT.find(raw)?.groupValues?.get(1)?.trim()?.trim('"', '\'')
            ?.takeIf { it.isNotBlank() }
        val serialNo = CUSTOM_SERIAL.find(raw)?.groupValues?.get(1)?.trim()?.trim('"', '\'')
            ?.takeIf { it.isNotBlank() }
        val variantCode = CUSTOM_VARIANT.find(raw)?.groupValues?.get(1)?.trim()?.trim('"', '\'')
            ?.takeIf { it.isNotBlank() }
        val unitOfMeasureCode = CUSTOM_UOM.find(raw)?.groupValues?.get(1)?.trim()?.trim('"', '\'')
            ?.takeIf { it.isNotBlank() }
        val quantity = CUSTOM_QUANTITY.find(raw)?.groupValues?.get(1)?.let(::parseLocalizedQuantity)

        if (itemNo == null && lotNo == null) return null
        if (itemNo == null) {
            return ResolvedBarcode(
                kind = BarcodeKind.Lot,
                value = lotNo!!,
                raw = raw,
                lotNo = lotNo,
                serialNo = serialNo,
                quantity = quantity,
                variantCode = variantCode,
                unitOfMeasureCode = unitOfMeasureCode,
            )
        }

        return ResolvedBarcode(
            kind = BarcodeKind.Item,
            value = itemNo,
            raw = raw,
            itemNo = itemNo,
            lotNo = lotNo,
            serialNo = serialNo,
            quantity = quantity,
            variantCode = variantCode,
            unitOfMeasureCode = unitOfMeasureCode,
        )
    }

    /** Türkçe etiketlerde 5,000/1,147 ADET binlik; 12,5 ise ondalık kabul edilir. */
    private fun parseLocalizedQuantity(value: String): Double? {
        var normalized = value.replace(" ", "").trim()
        if (normalized.isBlank()) return null

        normalized = when {
            normalized.contains(',') && normalized.contains('.') -> {
                val decimalSeparator = if (normalized.lastIndexOf(',') > normalized.lastIndexOf('.')) ',' else '.'
                val groupingSeparator = if (decimalSeparator == ',') '.' else ','
                normalized.replace(groupingSeparator.toString(), "").replace(decimalSeparator, '.')
            }
            Regex("^\\d{1,3}(,\\d{3})+$").matches(normalized) -> normalized.replace(",", "")
            Regex("^\\d{1,3}(\\.\\d{3})+$").matches(normalized) -> normalized.replace(".", "")
            normalized.contains(',') -> normalized.replace(',', '.')
            else -> normalized
        }
        return normalized.toDoubleOrNull()?.takeIf { it >= 0.0 }
    }

    private val CUSTOM_ITEM = Regex(
        """(?:madde\s*kodu|item\s*(?:no|code)|stok\s*kodu)[\"']?\s*[:=]\s*[\"']?([\p{L}\p{N}._/-]+)""",
        RegexOption.IGNORE_CASE,
    )
    private val CUSTOM_LOT = Regex(
        """(?:lot\s*(?:no|number)?|tedarikci\s*lotu|tedarikçi\s*lotu)[\"']?\s*[:=]\s*[\"']?([\p{L}\p{N}._/-]+)""",
        RegexOption.IGNORE_CASE,
    )
    private val CUSTOM_SERIAL = Regex(
        """(?:seri\s*(?:no|number)?|serial\s*(?:no|number)?|sn)[\"']?\s*[:=]\s*[\"']?([\p{L}\p{N}._/-]+)""",
        RegexOption.IGNORE_CASE,
    )
    private val CUSTOM_VARIANT = Regex(
        """(?:varyant(?:\s*kodu)?|variant(?:\s*(?:no|code))?)[\"']?\s*[:=]\s*[\"']?([\p{L}\p{N}._/-]+)""",
        RegexOption.IGNORE_CASE,
    )
    private val CUSTOM_UOM = Regex(
        """(?<![/\p{L}])(?:birim|ölçü\s*birimi|olcu\s*birimi|uom|unit\s*of\s*measure)[\"']?\s*[:=]\s*[\"']?([\p{L}\p{N}._/-]+)""",
        RegexOption.IGNORE_CASE,
    )
    private val CUSTOM_QUANTITY = Regex(
        """(?:miktar(?:\s*/\s*birim)?|quantity|qty)[\"']?\s*[:=]\s*[\"']?([0-9][0-9., ]*)""",
        RegexOption.IGNORE_CASE,
    )
}
