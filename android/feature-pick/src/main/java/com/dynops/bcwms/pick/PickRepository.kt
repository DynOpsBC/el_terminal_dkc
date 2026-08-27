package com.dynops.bcwms.pick

import com.dynops.bcwms.entity.PickActionType
import com.dynops.bcwms.entity.PickDoc
import com.dynops.bcwms.entity.PickLine
import com.dynops.bcwms.entity.ShortPickReason

interface PickRepository {
  suspend fun fetchPicks(assignedToMe: Boolean): Result<List<PickDoc>>
  suspend fun assignToMe(pickNo: String): Result<Unit>
  suspend fun confirmLine(pickNo: String, lineNo: Int, qtyToHandle: Double, binCode: String, licensePlateNo: String): Result<Unit>
  suspend fun startShippingLp(pickNo: String, templateCode: String? = null): Result<String>
  suspend fun stopShippingLp(pickNo: String, lpNo: String): Result<String>
  suspend fun markShort(pickNo: String, lineNo: Int, qty: Double, reasonCode: String): Result<Unit>
  suspend fun register(pickNo: String): Result<Unit>
  suspend fun reassign(pickNo: String, userId: String): Result<Unit>
  suspend fun shortPickReasons(): Result<List<ShortPickReason>>
}

class DefaultPickRepository : PickRepository {
  private val documents = mutableListOf(
    PickDoc(
      no = "PICK-S5-0001",
      sourceNo = "SHIP-1001",
      locationCode = "BLUE",
      assignedUserId = "MOBILE",
      status = "Open",
      percentComplete = 20.0,
      lines = listOf(
        PickLine(10000, "ITEM-A", "Take ITEM-A", PickActionType.TAKE, "BULK", 5.0, 5.0),
        PickLine(20000, "ITEM-A", "Place ITEM-A", PickActionType.PLACE, "SHIP", 5.0, 5.0),
      ),
    ),
    PickDoc(
      no = "PICK-S5-0002",
      sourceNo = "SHIP-1002",
      locationCode = "BLUE",
      assignedUserId = "ADA",
      status = "InProgress",
      percentComplete = 45.0,
      lines = listOf(PickLine(10000, "ITEM-B", "Take ITEM-B", PickActionType.TAKE, "A-01", 2.0, 2.0)),
    ),
  )

  override suspend fun fetchPicks(assignedToMe: Boolean): Result<List<PickDoc>> = runCatching {
    if (assignedToMe) documents.filter { it.assignedUserId.equals("MOBILE", ignoreCase = true) } else documents
  }

  override suspend fun assignToMe(pickNo: String): Result<Unit> = runCatching {
    replaceDoc(pickNo) { it.copy(assignedUserId = "MOBILE", status = "InProgress") }
  }

  override suspend fun confirmLine(pickNo: String, lineNo: Int, qtyToHandle: Double, binCode: String, licensePlateNo: String): Result<Unit> = runCatching {
    require(qtyToHandle >= 0) { "Quantity cannot be negative" }
    replaceLine(pickNo, lineNo) { it.copy(qtyToHandle = qtyToHandle, binCode = binCode, licensePlateNo = licensePlateNo) }
  }

  override suspend fun startShippingLp(pickNo: String, templateCode: String?): Result<String> = runCatching {
    require(doc(pickNo) != null) { "Pick not found" }
    "LP-S5-${pickNo.takeLast(4)}"
  }

  override suspend fun stopShippingLp(pickNo: String, lpNo: String): Result<String> = runCatching {
    require(doc(pickNo) != null) { "Pick not found" }
    require(lpNo.isNotBlank()) { "LP is required" }
    "003869012345678901"
  }

  override suspend fun markShort(pickNo: String, lineNo: Int, qty: Double, reasonCode: String): Result<Unit> = runCatching {
    require(reasonCode.isNotBlank()) { "Reason is required" }
    replaceLine(pickNo, lineNo) { it.copy(qtyToHandle = qty) }
  }

  override suspend fun register(pickNo: String): Result<Unit> = runCatching {
    replaceDoc(pickNo) { it.copy(status = "Done", percentComplete = 100.0) }
  }

  override suspend fun reassign(pickNo: String, userId: String): Result<Unit> = runCatching {
    replaceDoc(pickNo) { it.copy(assignedUserId = userId) }
  }

  override suspend fun shortPickReasons(): Result<List<ShortPickReason>> = runCatching {
    listOf(
      ShortPickReason("NO_STOCK", "No stock available", isDefault = true, allowsBackorder = true),
      ShortPickReason("DAMAGED", "Damaged inventory"),
      ShortPickReason("EXPIRED", "Expired inventory"),
      ShortPickReason("MISSING", "Inventory missing from bin"),
      ShortPickReason("LOT_NOT_FOUND", "Expected lot was not found"),
    )
  }

  private fun doc(pickNo: String) = documents.firstOrNull { it.no == pickNo }
  private fun replaceDoc(pickNo: String, transform: (PickDoc) -> PickDoc) {
    val index = documents.indexOfFirst { it.no == pickNo }
    require(index >= 0) { "Pick not found" }
    documents[index] = transform(documents[index])
  }
  private fun replaceLine(pickNo: String, lineNo: Int, transform: (PickLine) -> PickLine) {
    replaceDoc(pickNo) { doc -> doc.copy(lines = doc.lines.map { if (it.lineNo == lineNo) transform(it) else it }) }
  }
}
