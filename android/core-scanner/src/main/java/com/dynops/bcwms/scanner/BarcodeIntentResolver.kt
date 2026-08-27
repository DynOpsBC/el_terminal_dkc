package com.dynops.bcwms.scanner

sealed interface BarcodeIntent {
  data class Bin(val code: String) : BarcodeIntent
  data class Item(val itemReference: String, val gtin: String? = null, val lot: String? = null, val expiry: String? = null, val serial: String? = null) : BarcodeIntent
  data class Lp(val sscc: String) : BarcodeIntent
  data class LpTemplate(val code: String) : BarcodeIntent
  data class Lot(val code: String) : BarcodeIntent
  data class Serial(val code: String) : BarcodeIntent
  data class Unknown(val raw: String) : BarcodeIntent
}

class BarcodeIntentResolver {
  private val ean13 = Regex("""^\d{13}$""")
  private val gs1Full = Regex("""^\(01\)(?<gtin>\d{14})(\(10\)(?<lot>[A-Za-z0-9\-]+))?(\(17\)(?<exp>\d{6}))?(\(21\)(?<sn>[A-Za-z0-9\-]+))?$""")
  private val sscc18 = Regex("""^\(00\)(\d{18})$""")
  private val binPrefix = Regex("""^B-(?<bin>[\w-]+)$""")
  private val lpTemplate = Regex("""^TPL-(?<tpl>[\w-]+)$""")

  fun resolve(raw: String): BarcodeIntent {
    if (raw.isBlank()) return BarcodeIntent.Unknown(raw)
    if (ean13.matches(raw)) return BarcodeIntent.Item(itemReference = raw)

    gs1Full.matchEntire(raw)?.let { match ->
      return BarcodeIntent.Item(
        itemReference = match.groups["gtin"]!!.value,
        gtin = match.groups["gtin"]?.value,
        lot = match.groups["lot"]?.value,
        expiry = match.groups["exp"]?.value,
        serial = match.groups["sn"]?.value,
      )
    }

    sscc18.matchEntire(raw)?.let { return BarcodeIntent.Lp(it.groupValues[1]) }
    binPrefix.matchEntire(raw)?.let { return BarcodeIntent.Bin(it.groups["bin"]!!.value) }
    lpTemplate.matchEntire(raw)?.let { return BarcodeIntent.LpTemplate(it.groups["tpl"]!!.value) }
    return BarcodeIntent.Unknown(raw)
  }
}
