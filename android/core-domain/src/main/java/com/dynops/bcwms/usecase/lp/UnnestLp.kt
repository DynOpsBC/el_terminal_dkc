package com.dynops.bcwms.usecase.lp

data class UnnestLpRequest(val childLpNo: String)

class UnnestLp(private val executeRequest: suspend (UnnestLpRequest) -> Result<Unit>) {
  suspend operator fun invoke(request: UnnestLpRequest): Result<Unit> = executeRequest(request)
}
