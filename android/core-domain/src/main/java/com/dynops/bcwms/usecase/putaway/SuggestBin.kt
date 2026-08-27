package com.dynops.bcwms.usecase.putaway

class SuggestBin(
  private val executeRequest: suspend (itemNo: String, qty: Double, locationCode: String) -> Result<String>,
) {
  suspend operator fun invoke(itemNo: String, qty: Double, locationCode: String): Result<String> =
    executeRequest(itemNo, qty, locationCode)
}
