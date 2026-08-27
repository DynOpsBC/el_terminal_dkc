package com.dynops.bcwms.usecase.lp

data class NestLpRequest(val childLpNo: String, val parentLpNo: String)

class NestLp(private val executeRequest: suspend (NestLpRequest) -> Result<Unit>) {
  suspend operator fun invoke(request: NestLpRequest): Result<Unit> = executeRequest(request)
}
