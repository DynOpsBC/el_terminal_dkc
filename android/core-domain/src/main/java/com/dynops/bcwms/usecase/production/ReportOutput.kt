package com.dynops.bcwms.usecase.production

data class ReportOutputRequest(
  val prodOrderNo: String,
  val routingLineNo: Int,
  val outputQty: Double,
  val scrapQty: Double,
  val runtime: Double,
  val newLpTemplate: String? = null,
  val binCode: String? = null,
)

class ReportOutput(private val executeRequest: suspend (ReportOutputRequest) -> Result<String?>) {
  suspend operator fun invoke(request: ReportOutputRequest): Result<String?> = executeRequest(request)
}
