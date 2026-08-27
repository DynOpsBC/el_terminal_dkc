package com.dynops.bcwms.usecase.lp

data class StopLpRequest(val lpNo: String, val printLabel: Boolean = false)

class StopLp(private val executeRequest: suspend (StopLpRequest) -> Result<Unit>) {
  suspend operator fun invoke(request: StopLpRequest): Result<Unit> = executeRequest(request)
}
