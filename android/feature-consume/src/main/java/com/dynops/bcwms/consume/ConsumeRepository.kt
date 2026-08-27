package com.dynops.bcwms.consume

import com.dynops.bcwms.entity.ProdOrder
import com.dynops.bcwms.entity.ProdOrderComponent
import com.dynops.bcwms.usecase.production.ConsumeRequest

interface ConsumeRepository {
  suspend fun listReleasedProdOrders(): Result<List<ProdOrder>>
  suspend fun getComponents(prodOrderNo: String): Result<List<ProdOrderComponent>>
  suspend fun consume(request: ConsumeRequest): Result<Unit>
}

class DefaultConsumeRepository : ConsumeRepository {
  private val orders = mutableListOf(
    ProdOrder("PROD-S7-0001", itemNo = "FG-S7-A", description = "Mobile demo production order", quantity = 10.0, dueDate = "2026-05-28", locationCode = "BLUE", binCode = "OUTPUT"),
    ProdOrder("PROD-S7-0002", itemNo = "FG-S7-B", description = "Assembly cell order", quantity = 6.0, dueDate = "2026-05-29", locationCode = "BLUE", binCode = "OUTPUT"),
  )
  private val components = mutableMapOf(
    "PROD-S7-0001" to mutableListOf(
      ProdOrderComponent("PROD-S7-0001", 10000, "COMP-S7-A", "Frame", 10.0, 10.0, binCode = "PROD"),
      ProdOrderComponent("PROD-S7-0001", 20000, "COMP-S7-B", "Fastener pack", 20.0, 20.0, binCode = "PROD"),
    ),
    "PROD-S7-0002" to mutableListOf(
      ProdOrderComponent("PROD-S7-0002", 10000, "COMP-S7-C", "Harness", 6.0, 6.0, binCode = "PROD"),
    ),
  )

  override suspend fun listReleasedProdOrders(): Result<List<ProdOrder>> = Result.success(orders)

  override suspend fun getComponents(prodOrderNo: String): Result<List<ProdOrderComponent>> =
    Result.success(components[prodOrderNo].orEmpty())

  override suspend fun consume(request: ConsumeRequest): Result<Unit> = runCatching {
    require(request.qty > 0) { "Quantity must be greater than zero" }
    val lines = components[request.prodOrderNo] ?: error("Production order not found")
    val index = lines.indexOfFirst { it.lineNo == request.componentLineNo }
    require(index >= 0) { "Component line not found" }
    val line = lines[index]
    require(request.itemNo == line.itemNo) { "Scanned item does not match component" }
    lines[index] = line.copy(
      remainingQuantity = (line.remainingQuantity - request.qty).coerceAtLeast(0.0),
      lpNo = request.lpNo,
      lotNo = request.lotNo,
      serialNo = request.serialNo,
      binCode = request.binCode ?: line.binCode,
    )
  }
}
