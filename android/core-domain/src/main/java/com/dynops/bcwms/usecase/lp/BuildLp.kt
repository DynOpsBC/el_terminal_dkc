package com.dynops.bcwms.usecase.lp

data class BuildLpRequest(val templateCode: String, val locationCode: String, val binCode: String)

class BuildLp(private val executeRequest: suspend (BuildLpRequest) -> Result<String>) {
  suspend operator fun invoke(request: BuildLpRequest): Result<String> = executeRequest(request)
}
