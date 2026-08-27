package com.dynops.bcwms.usecase.receipt

data class StopReceiptLpRequest(val receiptNo: String, val lpNo: String, val printLabel: Boolean = false)

class StopReceiptLp(private val executeRequest: suspend (StopReceiptLpRequest) -> Result<Unit>) {
  suspend operator fun invoke(request: StopReceiptLpRequest): Result<Unit> = executeRequest(request)
}
