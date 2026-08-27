package com.dynops.bcwms.usecase.putaway

data class ConfirmPutAwayLineRequest(
  val docId: String,
  val lineNo: Int,
  val qtyToHandle: Double,
  val binCode: String,
  val lpNo: String,
)

class ConfirmPutAwayLine(
  private val executeRequest: suspend (ConfirmPutAwayLineRequest) -> Result<Unit>,
) {
  suspend operator fun invoke(docId: String, lineNo: Int, qtyToHandle: Double, binCode: String, lpNo: String): Result<Unit> =
    executeRequest(ConfirmPutAwayLineRequest(docId, lineNo, qtyToHandle, binCode, lpNo))

  suspend operator fun invoke(request: ConfirmPutAwayLineRequest): Result<Unit> = executeRequest(request)
}
