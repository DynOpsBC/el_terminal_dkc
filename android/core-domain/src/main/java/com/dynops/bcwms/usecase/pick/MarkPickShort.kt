package com.dynops.bcwms.usecase.pick

class MarkPickShort(private val executeRequest: suspend (pickNo: String, lineNo: Int, qty: Double, reasonCode: String) -> Result<Unit>) {
  suspend operator fun invoke(pickNo: String, lineNo: Int, qty: Double, reasonCode: String): Result<Unit> =
    executeRequest(pickNo, lineNo, qty, reasonCode)
}
