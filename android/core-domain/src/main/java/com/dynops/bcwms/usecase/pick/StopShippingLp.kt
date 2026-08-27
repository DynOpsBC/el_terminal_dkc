package com.dynops.bcwms.usecase.pick

class StopShippingLp(private val executeRequest: suspend (pickNo: String, lpNo: String, printLabel: Boolean) -> Result<String>) {
  suspend operator fun invoke(pickNo: String, lpNo: String, printLabel: Boolean = true): Result<String> =
    executeRequest(pickNo, lpNo, printLabel)
}
