package com.dynops.bcwms.printer

import android.content.SharedPreferences

data class Printer(
  val id: String,
  val name: String,
  val address: String? = null,
)

class PrinterRegistry(
  private val preferences: SharedPreferences,
) {
  fun getDefaultPrinter(): Printer? {
    val id = preferences.getString(KEY_DEFAULT_ID, null) ?: return null
    val name = preferences.getString(printerNameKey(id), id) ?: id
    val address = preferences.getString(printerAddressKey(id), null)
    return Printer(id = id, name = name, address = address)
  }

  fun setDefaultPrinter(id: String) {
    preferences.edit()
      .putString(KEY_DEFAULT_ID, id)
      .apply()
    rememberPrinter(Printer(id = id, name = preferences.getString(printerNameKey(id), id) ?: id))
  }

  fun rememberPrinter(printer: Printer) {
    val ids = recentPrinterIds().filterNot { it == printer.id }.toMutableList()
    ids.add(0, printer.id)
    preferences.edit()
      .putString(KEY_RECENT_IDS, ids.take(MAX_RECENT).joinToString("|"))
      .putString(printerNameKey(printer.id), printer.name)
      .putString(printerAddressKey(printer.id), printer.address)
      .apply()
  }

  fun recentPrinters(): List<Printer> =
    recentPrinterIds().map { id ->
      Printer(
        id = id,
        name = preferences.getString(printerNameKey(id), id) ?: id,
        address = preferences.getString(printerAddressKey(id), null),
      )
    }

  private fun recentPrinterIds(): List<String> =
    preferences.getString(KEY_RECENT_IDS, null)
      ?.split("|")
      ?.filter { it.isNotBlank() }
      .orEmpty()

  private fun printerNameKey(id: String) = "printer.$id.name"

  private fun printerAddressKey(id: String) = "printer.$id.address"

  private companion object {
    const val KEY_DEFAULT_ID = "defaultPrinterId"
    const val KEY_RECENT_IDS = "recentPrinterIds"
    const val MAX_RECENT = 5
  }
}
