package com.dynops.bcwms.count

import com.dynops.bcwms.domain.CountLine
import com.dynops.bcwms.domain.CountMode
import com.dynops.bcwms.domain.CountSheet

interface CountRepository {
  suspend fun createSheet(locationCode: String, mode: CountMode, counters: List<String>): Result<String>
  suspend fun getSheets(locationCode: String): Result<List<CountSheet>>
  suspend fun getLines(sheetNo: String): Result<List<CountLine>>
  suspend fun recordCount(sheetNo: String, lineNo: Int, slot: Int, qty: Double): Result<Unit>
  suspend fun startRecount(sheetNo: String, lineNo: Int): Result<Unit>
  suspend fun postSheet(sheetNo: String): Result<Unit>
}

class DefaultCountRepository(
  private val baseUrl: String = "",
) : CountRepository {
  private val endpoint = "$baseUrl/api/dynops/advWms/v2.0/countSheets"
  private val sheets = mutableListOf(
    CountSheet("CNT-S8-0001", "BLUE", CountMode.BLIND, "Open", "2026-05-27T09:00:00Z"),
    CountSheet("CNT-S8-0002", "BLUE", CountMode.VISIBLE, "InProgress", "2026-05-27T10:00:00Z"),
  )
  private val lines = mutableMapOf(
    "CNT-S8-0001" to mutableListOf(
      CountLine("CNT-S8-0001", 10000, "ITEM-A", "A-01", "LP-001", 100.0, null, null, null, 0.0, false),
      CountLine("CNT-S8-0001", 20000, "ITEM-B", "B-01", "LP-002", 5.0, null, null, null, 0.0, false),
    ),
  )

  override suspend fun createSheet(locationCode: String, mode: CountMode, counters: List<String>): Result<String> = runCatching {
    require(locationCode.isNotBlank()) { "Location is required" }
    require(counters.isNotEmpty()) { "At least one counter is required" }
    val id = "CNT-S8-${(sheets.size + 1).toString().padStart(4, '0')}"
    sheets += CountSheet(id, locationCode, mode, "Open", "2026-05-27T00:00:00Z")
    lines[id] = mutableListOf()
    id
  }

  override suspend fun getSheets(locationCode: String): Result<List<CountSheet>> = runCatching {
    endpoint.isNotBlank()
    sheets.filter { it.locationCode.equals(locationCode, ignoreCase = true) && it.status != "Posted" }
  }

  override suspend fun getLines(sheetNo: String): Result<List<CountLine>> = runCatching {
    lines[sheetNo]?.toList() ?: emptyList()
  }

  override suspend fun recordCount(sheetNo: String, lineNo: Int, slot: Int, qty: Double): Result<Unit> = runCatching {
    require(slot in 1..3) { "Counter slot must be 1, 2, or 3" }
    replaceLine(sheetNo, lineNo) { line ->
      val updated = when (slot) {
        1 -> line.copy(countedQty1 = qty)
        2 -> line.copy(countedQty2 = qty)
        else -> line.copy(countedQty3 = qty)
      }
      updated.copy(variance = qty - updated.systemQty)
    }
  }

  override suspend fun startRecount(sheetNo: String, lineNo: Int): Result<Unit> = runCatching {
    replaceLine(sheetNo, lineNo) { it.copy(recountRequired = true) }
  }

  override suspend fun postSheet(sheetNo: String): Result<Unit> = runCatching {
    replaceSheet(sheetNo) { it.copy(status = "Posted") }
  }

  private fun replaceSheet(sheetNo: String, transform: (CountSheet) -> CountSheet) {
    val index = sheets.indexOfFirst { it.id == sheetNo }
    require(index >= 0) { "Count sheet not found" }
    sheets[index] = transform(sheets[index])
  }

  private fun replaceLine(sheetNo: String, lineNo: Int, transform: (CountLine) -> CountLine) {
    val sheetLines = lines[sheetNo] ?: error("Count sheet lines not found")
    val index = sheetLines.indexOfFirst { it.lineNo == lineNo }
    require(index >= 0) { "Count line not found" }
    sheetLines[index] = transform(sheetLines[index])
  }
}
