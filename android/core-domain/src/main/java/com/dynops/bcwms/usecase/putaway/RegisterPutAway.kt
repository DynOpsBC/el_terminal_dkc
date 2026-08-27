package com.dynops.bcwms.usecase.putaway

class RegisterPutAway(
  private val executeRequest: suspend (docId: String) -> Result<Unit>,
) {
  suspend operator fun invoke(docId: String): Result<Unit> = executeRequest(docId)
}
