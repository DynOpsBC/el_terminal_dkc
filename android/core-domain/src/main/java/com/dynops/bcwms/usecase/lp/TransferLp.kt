package com.dynops.bcwms.usecase.lp

data class TransferLpRequest(val sourceLpNo: String, val targetLpNo: String?, val lineQuantities: Map<Int, Double>)

class TransferLp(private val executeRequest: suspend (TransferLpRequest) -> Result<String>) {
  suspend operator fun invoke(request: TransferLpRequest): Result<String> = executeRequest(request)
}
