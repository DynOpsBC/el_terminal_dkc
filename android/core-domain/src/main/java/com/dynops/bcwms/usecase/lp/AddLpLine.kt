package com.dynops.bcwms.usecase.lp

data class AddLpLineRequest(
  val lpNo: String,
  val itemNo: String,
  val quantity: Double,
  val unitOfMeasure: String,
  val lotNo: String? = null,
  val serialNo: String? = null,
)

class AddLpLine(private val executeRequest: suspend (AddLpLineRequest) -> Result<Unit>) {
  suspend operator fun invoke(request: AddLpLineRequest): Result<Unit> = executeRequest(request)
}
