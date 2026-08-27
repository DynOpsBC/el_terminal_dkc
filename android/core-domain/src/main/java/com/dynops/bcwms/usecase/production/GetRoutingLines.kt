package com.dynops.bcwms.usecase.production

import com.dynops.bcwms.entity.ProdOrderRouting

class GetRoutingLines(private val executeRequest: suspend (prodOrderNo: String) -> Result<List<ProdOrderRouting>>) {
  suspend operator fun invoke(prodOrderNo: String): Result<List<ProdOrderRouting>> = executeRequest(prodOrderNo)
}
