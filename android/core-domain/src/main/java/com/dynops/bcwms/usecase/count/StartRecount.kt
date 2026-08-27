package com.dynops.bcwms.usecase.count

class StartRecount(
  private val executeRequest: suspend (sheetNo: String, lineNo: Int) -> Result<Unit>,
) {
  suspend operator fun invoke(sheetNo: String, lineNo: Int): Result<Unit> = executeRequest(sheetNo, lineNo)
}
