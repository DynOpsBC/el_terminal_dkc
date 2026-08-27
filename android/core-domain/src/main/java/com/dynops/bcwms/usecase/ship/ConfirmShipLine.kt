package com.dynops.bcwms.usecase.ship

class ConfirmShipLine(
  private val executeRequest: suspend (documentNo: String, lineNo: Int, qtyToShip: Double, licensePlateNo: String, sscc: String?) -> Result<Unit>,
) {
  suspend operator fun invoke(documentNo: String, lineNo: Int, qtyToShip: Double, licensePlateNo: String, sscc: String? = null): Result<Unit> =
    executeRequest(documentNo, lineNo, qtyToShip, licensePlateNo, sscc)
}
