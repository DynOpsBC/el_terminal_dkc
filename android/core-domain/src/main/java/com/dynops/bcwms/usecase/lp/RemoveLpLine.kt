package com.dynops.bcwms.usecase.lp

data class RemoveLpLineRequest(val lpNo: String, val lineNo: Int)

class RemoveLpLine(private val executeRequest: suspend (RemoveLpLineRequest) -> Result<Unit>) {
  suspend operator fun invoke(request: RemoveLpLineRequest): Result<Unit> = executeRequest(request)
}
