package com.dynops.bcwms.assembly

import com.dynops.bcwms.entity.AssemblyLine
import com.dynops.bcwms.entity.AssemblyOrder

interface AssemblyRepository {
  suspend fun listAssemblies(): Result<List<AssemblyOrder>>
  suspend fun getLines(assemblyNo: String): Result<List<AssemblyLine>>
  suspend fun postAssembly(assemblyNo: String, quantity: Double): Result<Unit>
}

class DefaultAssemblyRepository : AssemblyRepository {
  private val assemblies = mutableListOf(
    AssemblyOrder("ASM-S7-0001", itemNo = "KIT-S7-A", description = "Assemble-to-stock kit", quantity = 5.0, remainingQuantity = 5.0, dueDate = "2026-05-28", locationCode = "BLUE", binCode = "ASSEMBLY"),
    AssemblyOrder("ASM-S7-0002", itemNo = "KIT-S7-B", description = "ATO tracking order", quantity = 2.0, remainingQuantity = 2.0, dueDate = "2026-05-29", locationCode = "BLUE", binCode = "ASSEMBLY", assembleToOrder = true),
  )
  private val lines = mapOf(
    "ASM-S7-0001" to listOf(
      AssemblyLine("ASM-S7-0001", 10000, "COMP-S7-A", "Frame", 5.0, binCode = "ASSEMBLY"),
      AssemblyLine("ASM-S7-0001", 20000, "COMP-S7-B", "Fastener pack", 10.0, binCode = "ASSEMBLY"),
    ),
    "ASM-S7-0002" to listOf(AssemblyLine("ASM-S7-0002", 10000, "COMP-S7-C", "Harness", 2.0, binCode = "ASSEMBLY")),
  )

  override suspend fun listAssemblies(): Result<List<AssemblyOrder>> = Result.success(assemblies)
  override suspend fun getLines(assemblyNo: String): Result<List<AssemblyLine>> = Result.success(lines[assemblyNo].orEmpty())
  override suspend fun postAssembly(assemblyNo: String, quantity: Double): Result<Unit> = runCatching {
    require(quantity > 0) { "Assembly quantity must be greater than zero" }
    assemblies.removeAll { it.no == assemblyNo }
  }
}
