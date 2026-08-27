package com.dynops.bcwms.usecase.ship

class PostShipment(
  private val executeRequest: suspend (shipmentNo: String, print: Boolean, invoice: Boolean) -> Result<Unit>,
) {
  suspend operator fun invoke(shipmentNo: String, print: Boolean = false, invoice: Boolean = false): Result<Unit> =
    executeRequest(shipmentNo, print, invoice)
}
