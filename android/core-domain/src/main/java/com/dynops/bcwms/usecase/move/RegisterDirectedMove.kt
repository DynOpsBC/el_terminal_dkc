package com.dynops.bcwms.usecase.move

class RegisterDirectedMove(
  private val executeRequest: suspend (docId: String) -> Result<Unit>,
) {
  suspend operator fun invoke(docId: String): Result<Unit> = executeRequest(docId)
}
