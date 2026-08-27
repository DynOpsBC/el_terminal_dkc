package com.dynops.bcwms.usecase.receipt

import com.dynops.bcwms.entity.Receipt

data class ReceiptFilter(val search: String = "", val assignedUserId: String? = null, val locationCode: String? = null)

class GetReceipts(private val executeRequest: suspend (ReceiptFilter) -> Result<List<Receipt>>) {
  suspend operator fun invoke(filter: ReceiptFilter = ReceiptFilter()): Result<List<Receipt>> = executeRequest(filter)
}
