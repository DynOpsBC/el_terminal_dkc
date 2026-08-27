package com.dynops.bcwms.usecase.receipt

data class AssignReceiptToUserRequest(val receiptNo: String, val userId: String)

class AssignReceiptToUser(private val executeRequest: suspend (AssignReceiptToUserRequest) -> Result<Unit>) {
  suspend operator fun invoke(request: AssignReceiptToUserRequest): Result<Unit> = executeRequest(request)
}
