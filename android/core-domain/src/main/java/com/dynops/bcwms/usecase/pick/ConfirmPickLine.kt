package com.dynops.bcwms.usecase.pick

class ConfirmPickLine(private val executeRequest: suspend (pickNo: String, lineNo: Int, qtyToHandle: Double, binCode: String, licensePlateNo: String) -> Result<Unit>) {
  suspend operator fun invoke(pickNo: String, lineNo: Int, qtyToHandle: Double, binCode: String, licensePlateNo: String): Result<Unit> =
    executeRequest(pickNo, lineNo, qtyToHandle, binCode, licensePlateNo)
}
