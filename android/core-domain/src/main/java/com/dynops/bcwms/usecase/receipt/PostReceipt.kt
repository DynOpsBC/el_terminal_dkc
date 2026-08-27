package com.dynops.bcwms.usecase.receipt

data class PostReceiptRequest(val receiptNo: String, val print: Boolean = false, val invoice: Boolean = false)

class PostReceipt(private val executeRequest: suspend (PostReceiptRequest) -> Result<Unit>) {
  suspend operator fun invoke(request: PostReceiptRequest): Result<Unit> = executeRequest(request)
}
