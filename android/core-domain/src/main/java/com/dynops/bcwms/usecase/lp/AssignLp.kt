package com.dynops.bcwms.usecase.lp

import com.dynops.bcwms.entity.AssignedDocType

data class AssignLpRequest(val lpNo: String, val docType: AssignedDocType, val docNo: String)

class AssignLp(private val executeRequest: suspend (AssignLpRequest) -> Result<Unit>) {
  suspend operator fun invoke(request: AssignLpRequest): Result<Unit> = executeRequest(request)
}
