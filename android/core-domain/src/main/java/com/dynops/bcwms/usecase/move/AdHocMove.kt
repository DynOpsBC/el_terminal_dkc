package com.dynops.bcwms.usecase.move

data class AdHocMoveRequest(
  val fromBin: String,
  val toBin: String,
  val itemNo: String,
  val lpNo: String,
  val qty: Double,
)

class AdHocMove(
  private val executeRequest: suspend (AdHocMoveRequest) -> Result<Unit>,
) {
  suspend operator fun invoke(fromBin: String, toBin: String, itemNo: String, lpNo: String, qty: Double): Result<Unit> =
    executeRequest(AdHocMoveRequest(fromBin, toBin, itemNo, lpNo, qty))

  suspend operator fun invoke(request: AdHocMoveRequest): Result<Unit> = executeRequest(request)
}
