package com.dynops.bcwms.usecase.production

import com.dynops.bcwms.entity.ProdOrderComponent

class GetComponents(private val executeRequest: suspend (prodOrderNo: String) -> Result<List<ProdOrderComponent>>) {
  suspend operator fun invoke(prodOrderNo: String): Result<List<ProdOrderComponent>> = executeRequest(prodOrderNo)
}
