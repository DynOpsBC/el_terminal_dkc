package com.dynops.bcwms.usecase.receipt

data class ConfirmReceiptLineRequest(
  val receiptNo: String,
  val lineNo: Int,
  val qtyToReceive: Double,
  val lotNo: String? = null,
  val serialNo: String? = null,
  val expiryDate: String? = null,
  val licensePlateNo: String? = null,
  val binCode: String? = null,
)

class ConfirmReceiptLine(private val executeRequest: suspend (ConfirmReceiptLineRequest) -> Result<Unit>) {
  suspend operator fun invoke(request: ConfirmReceiptLineRequest): Result<Unit> = executeRequest(request)
}
