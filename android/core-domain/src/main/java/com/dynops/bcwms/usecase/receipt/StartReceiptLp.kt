package com.dynops.bcwms.usecase.receipt

data class StartReceiptLpRequest(val receiptNo: String, val lpTemplateCode: String? = null)

class StartReceiptLp(private val executeRequest: suspend (StartReceiptLpRequest) -> Result<String>) {
  suspend operator fun invoke(request: StartReceiptLpRequest): Result<String> = executeRequest(request)
}
