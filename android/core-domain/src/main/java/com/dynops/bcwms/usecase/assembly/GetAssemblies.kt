package com.dynops.bcwms.usecase.assembly

import com.dynops.bcwms.entity.AssemblyLine
import com.dynops.bcwms.entity.AssemblyOrder

class GetAssemblies(
  private val executeRequest: suspend (status: String) -> Result<List<AssemblyOrder>>,
  private val lineRequest: suspend (assemblyNo: String) -> Result<List<AssemblyLine>> = { Result.success(emptyList()) },
) {
  suspend operator fun invoke(status: String = "Released"): Result<List<AssemblyOrder>> = executeRequest(status)
  suspend fun lines(assemblyNo: String): Result<List<AssemblyLine>> = lineRequest(assemblyNo)
}
