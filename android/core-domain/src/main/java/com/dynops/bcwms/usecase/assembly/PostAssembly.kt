package com.dynops.bcwms.usecase.assembly

class PostAssembly(private val executeRequest: suspend (assemblyNo: String, quantity: Double) -> Result<Unit>) {
  suspend operator fun invoke(assemblyNo: String, quantity: Double): Result<Unit> = executeRequest(assemblyNo, quantity)
}
