package com.dynops.bcwms.move

import com.dynops.bcwms.domain.entity.MoveDoc
import com.dynops.bcwms.domain.entity.MoveType

interface MoveRepository {
  suspend fun fetchMovements(type: String?): Result<List<MoveDoc>>
  suspend fun adHocMove(fromBin: String, toBin: String, itemNo: String, lpNo: String, qty: Double): Result<Unit>
  suspend fun registerDirected(docId: String): Result<Unit>
}

class DefaultMoveRepository : MoveRepository {
  private val directedMoves = mutableListOf(
    MoveDoc("MV-S4-0001", MoveType.DIRECTED, "PICK", "BULK", "ITEM-S4-A", "", 4.0, "Open"),
    MoveDoc("MV-S4-0002", MoveType.DIRECTED, "RECEIVE", "PUT-01", "ITEM-S4-B", "LP-S4-2", 1.0, "Open"),
  )

  override suspend fun fetchMovements(type: String?): Result<List<MoveDoc>> = runCatching {
    when (type?.uppercase()) {
      "ADHOC" -> emptyList()
      "DIRECTED" -> directedMoves
      else -> directedMoves
    }
  }

  override suspend fun adHocMove(fromBin: String, toBin: String, itemNo: String, lpNo: String, qty: Double): Result<Unit> = runCatching {
    require(fromBin.isNotBlank()) { "Source bin is required" }
    require(toBin.isNotBlank()) { "Target bin is required" }
    require(itemNo.isNotBlank() || lpNo.isNotBlank()) { "Item or LP is required" }
    require(qty > 0) { "Quantity must be greater than zero" }
  }

  override suspend fun registerDirected(docId: String): Result<Unit> = runCatching {
    val index = directedMoves.indexOfFirst { it.id == docId }
    require(index >= 0) { "Directed movement not found" }
    directedMoves[index] = directedMoves[index].copy(status = "Registered")
  }
}
