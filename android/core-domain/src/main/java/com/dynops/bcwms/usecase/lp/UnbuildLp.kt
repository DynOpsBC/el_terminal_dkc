package com.dynops.bcwms.usecase.lp

data class UnbuildLpRequest(val lpNo: String)

class UnbuildLp(private val executeRequest: suspend (UnbuildLpRequest) -> Result<Unit>) {
  suspend operator fun invoke(request: UnbuildLpRequest): Result<Unit> = executeRequest(request)
}
