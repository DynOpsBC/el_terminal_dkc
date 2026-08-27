package com.dynops.bcwms.usecase.lp

data class PrintLpLabelRequest(val lpNo: String, val printerId: String? = null, val copies: Int = 1)

class PrintLpLabel(private val executeRequest: suspend (PrintLpLabelRequest) -> Result<Unit>) {
  suspend operator fun invoke(request: PrintLpLabelRequest): Result<Unit> = executeRequest(request)
}
