package com.dynops.bcwms.usecase.ship

class PostShipAndInvoice(
  private val executeRequest: suspend (salesOrderNo: String) -> Result<Unit>,
) {
  suspend operator fun invoke(salesOrderNo: String): Result<Unit> = executeRequest(salesOrderNo)
}
