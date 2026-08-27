package com.dynops.bcwms.usecase.count

class PostCountSheet(
  private val executeRequest: suspend (sheetNo: String) -> Result<Unit>,
) {
  suspend operator fun invoke(sheetNo: String): Result<Unit> = executeRequest(sheetNo)
}
