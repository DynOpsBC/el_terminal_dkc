package com.dynops.bcwms.usecase.pick

class ReassignPick(private val executeRequest: suspend (pickNo: String, userId: String) -> Result<Unit>) {
  suspend operator fun invoke(pickNo: String, userId: String): Result<Unit> = executeRequest(pickNo, userId)
}
