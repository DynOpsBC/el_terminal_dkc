package com.dynops.bcwms.usecase.pick

class RegisterPick(private val executeRequest: suspend (pickNo: String) -> Result<Unit>) {
  suspend operator fun invoke(pickNo: String): Result<Unit> = executeRequest(pickNo)
}
