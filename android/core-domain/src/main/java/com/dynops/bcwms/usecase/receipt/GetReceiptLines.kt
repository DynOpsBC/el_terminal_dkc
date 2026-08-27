package com.dynops.bcwms.usecase.receipt

import com.dynops.bcwms.entity.ReceiptLine

class GetReceiptLines(private val executeRequest: suspend (String) -> Result<List<ReceiptLine>>) {
  suspend operator fun invoke(receiptNo: String): Result<List<ReceiptLine>> = executeRequest(receiptNo)
}
