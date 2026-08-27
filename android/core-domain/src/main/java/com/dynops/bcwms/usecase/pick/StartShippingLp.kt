package com.dynops.bcwms.usecase.pick

class StartShippingLp(private val executeRequest: suspend (pickNo: String, templateCode: String?) -> Result<String>) {
  suspend operator fun invoke(pickNo: String, templateCode: String? = null): Result<String> = executeRequest(pickNo, templateCode)
}
