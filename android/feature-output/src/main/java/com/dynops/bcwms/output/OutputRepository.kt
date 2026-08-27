package com.dynops.bcwms.output

import com.dynops.bcwms.entity.ProdOrder
import com.dynops.bcwms.entity.ProdOrderRouting
import com.dynops.bcwms.usecase.production.ReportOutputRequest

interface OutputRepository {
  suspend fun listReleasedProdOrders(): Result<List<ProdOrder>>
  suspend fun getRoutingLines(prodOrderNo: String): Result<List<ProdOrderRouting>>
  suspend fun reportOutput(request: ReportOutputRequest): Result<String?>
}

class DefaultOutputRepository : OutputRepository {
  private val orders = listOf(
    ProdOrder("PROD-S7-0001", itemNo = "FG-S7-A", description = "Mobile demo production order", quantity = 10.0, dueDate = "2026-05-28", locationCode = "BLUE", binCode = "OUTPUT"),
    ProdOrder("PROD-S7-0002", itemNo = "FG-S7-B", description = "Assembly cell order", quantity = 6.0, dueDate = "2026-05-29", locationCode = "BLUE", binCode = "OUTPUT"),
  )
  private val routing = mapOf(
    "PROD-S7-0001" to listOf(
      ProdOrderRouting("PROD-S7-0001", 10000, "10", "WC-10", "Cut"),
      ProdOrderRouting("PROD-S7-0001", 20000, "20", "WC-20", "Pack"),
    ),
    "PROD-S7-0002" to listOf(ProdOrderRouting("PROD-S7-0002", 10000, "10", "WC-30", "Build")),
  )

  override suspend fun listReleasedProdOrders(): Result<List<ProdOrder>> = Result.success(orders)
  override suspend fun getRoutingLines(prodOrderNo: String): Result<List<ProdOrderRouting>> = Result.success(routing[prodOrderNo].orEmpty())
  override suspend fun reportOutput(request: ReportOutputRequest): Result<String?> = runCatching {
    require(request.outputQty > 0 || request.scrapQty > 0) { "Output or scrap quantity is required" }
    if (request.newLpTemplate.isNullOrBlank()) null else "LP-OUT-${request.prodOrderNo.takeLast(4)}"
  }
}
