package com.dynops.bcwms.usecase.count

class RecordCount(
  private val executeRequest: suspend (sheetNo: String, lineNo: Int, slot: Int, qty: Double) -> Result<Unit>,
) {
  suspend operator fun invoke(sheetNo: String, lineNo: Int, slot: Int, qty: Double): Result<Unit> =
    executeRequest(sheetNo, lineNo, slot, qty)
}
