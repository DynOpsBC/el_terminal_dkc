package com.dynops.bcwms.usecase.production

data class ConsumeRequest(
  val prodOrderNo: String,
  val componentLineNo: Int,
  val itemNo: String,
  val qty: Double,
  val lpNo: String? = null,
  val lotNo: String? = null,
  val serialNo: String? = null,
  val binCode: String? = null,
)

class Consume(private val executeRequest: suspend (ConsumeRequest) -> Result<Unit>) {
  suspend operator fun invoke(request: ConsumeRequest): Result<Unit> = executeRequest(request)
}
