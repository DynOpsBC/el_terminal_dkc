package com.dynops.bcwms.usecase.production

import com.dynops.bcwms.entity.ProdOrder

class GetProdOrders(private val executeRequest: suspend (status: String) -> Result<List<ProdOrder>>) {
  suspend operator fun invoke(status: String = "Released"): Result<List<ProdOrder>> = executeRequest(status)
}
