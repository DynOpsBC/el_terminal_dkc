package com.dynops.bcwms.putaway

import com.dynops.bcwms.domain.entity.PutAwayDoc
import com.dynops.bcwms.domain.entity.PutAwayLine

interface PutAwayRepository {
  suspend fun fetchPutAways(userId: String): Result<List<PutAwayDoc>>
  suspend fun suggestBin(itemNo: String, qty: Double, locationCode: String): Result<String>
  suspend fun confirmLine(docId: String, lineNo: Int, qtyToHandle: Double, binCode: String, lpNo: String): Result<Unit>
  suspend fun register(docId: String): Result<Unit>
}

class DefaultPutAwayRepository : PutAwayRepository {
  private val documents = mutableListOf(
    PutAwayDoc(
      id = "PA-S4-0001",
      locationCode = "BLUE",
      assignedUserId = "MOBILE",
      status = "Open",
      lines = listOf(
        PutAwayLine(10000, "ITEM-S4-A", "RECEIVE", 5.0, "", ""),
        PutAwayLine(20000, "ITEM-S4-B", "RECEIVE", 2.0, "", ""),
      ),
    ),
    PutAwayDoc(
      id = "PA-S4-0002",
      locationCode = "BLUE",
      assignedUserId = "MOBILE",
      status = "Open",
      lines = listOf(PutAwayLine(10000, "ITEM-S4-C", "RECEIVE", 8.0, "", "")),
    ),
  )

  override suspend fun fetchPutAways(userId: String): Result<List<PutAwayDoc>> = runCatching {
    documents.filter { it.assignedUserId.equals(userId, ignoreCase = true) || userId.isBlank() }
  }

  override suspend fun suggestBin(itemNo: String, qty: Double, locationCode: String): Result<String> = runCatching {
    require(itemNo.isNotBlank()) { "Item is required" }
    require(qty > 0) { "Quantity must be greater than zero" }
    "$locationCode-PUT-${itemNo.takeLast(1).ifBlank { "A" }}"
  }

  override suspend fun confirmLine(docId: String, lineNo: Int, qtyToHandle: Double, binCode: String, lpNo: String): Result<Unit> = runCatching {
    require(qtyToHandle >= 0) { "Quantity cannot be negative" }
    replaceDocumentLine(docId, lineNo) { it.copy(qtyToHandle = qtyToHandle, binCode = binCode, lpNo = lpNo) }
  }

  override suspend fun register(docId: String): Result<Unit> = runCatching {
    val index = documents.indexOfFirst { it.id == docId }
    require(index >= 0) { "Put-away document not found" }
    documents[index] = documents[index].copy(status = "Registered")
  }

  private fun replaceDocumentLine(docId: String, lineNo: Int, transform: (PutAwayLine) -> PutAwayLine) {
    val index = documents.indexOfFirst { it.id == docId }
    require(index >= 0) { "Put-away document not found" }
    val doc = documents[index]
    documents[index] = doc.copy(lines = doc.lines.map { if (it.lineNo == lineNo) transform(it) else it })
  }
}
