package com.dynops.bcwms.assembly

import com.dynops.bcwms.entity.AssemblyLine
import com.dynops.bcwms.entity.AssemblyOrder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class AssemblyState(
  val assemblies: List<AssemblyOrder> = emptyList(),
  val selectedAssembly: AssemblyOrder? = null,
  val lines: List<AssemblyLine> = emptyList(),
  val assemblyQty: Double = 0.0,
  val loading: Boolean = false,
  val error: String? = null,
)

sealed interface AssemblyIntent {
  data object LoadList : AssemblyIntent
  data class OpenAssembly(val assembly: AssemblyOrder) : AssemblyIntent
  data class EditQuantity(val quantity: Double) : AssemblyIntent
  data object Post : AssemblyIntent
  data object ClearError : AssemblyIntent
}

class AssemblyViewModel(
  private val repository: AssemblyRepository,
  private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
) {
  private val mutableState = MutableStateFlow(AssemblyState())
  val state: StateFlow<AssemblyState> = mutableState.asStateFlow()

  fun handle(intent: AssemblyIntent) {
    when (intent) {
      AssemblyIntent.LoadList -> loadList()
      is AssemblyIntent.OpenAssembly -> openAssembly(intent.assembly)
      is AssemblyIntent.EditQuantity -> mutableState.value = mutableState.value.copy(assemblyQty = intent.quantity)
      AssemblyIntent.Post -> postAssembly()
      AssemblyIntent.ClearError -> mutableState.value = mutableState.value.copy(error = null)
    }
  }

  private fun loadList() {
    mutableState.value = mutableState.value.copy(loading = true, error = null)
    scope.launch {
      mutableState.value = repository.listAssemblies().fold(
        onSuccess = { mutableState.value.copy(assemblies = it, loading = false) },
        onFailure = { mutableState.value.copy(loading = false, error = it.message ?: "Assembly lookup failed") },
      )
    }
  }

  private fun openAssembly(assembly: AssemblyOrder) {
    mutableState.value = mutableState.value.copy(selectedAssembly = assembly, assemblyQty = assembly.remainingQuantity, loading = true, error = null)
    scope.launch {
      mutableState.value = repository.getLines(assembly.no).fold(
        onSuccess = { mutableState.value.copy(lines = it, loading = false) },
        onFailure = { mutableState.value.copy(loading = false, error = it.message ?: "Assembly lines failed") },
      )
    }
  }

  private fun postAssembly() {
    val assembly = mutableState.value.selectedAssembly ?: return
    mutableState.value = mutableState.value.copy(loading = true, error = null)
    scope.launch {
      mutableState.value = repository.postAssembly(assembly.no, mutableState.value.assemblyQty).fold(
        onSuccess = { mutableState.value.copy(selectedAssembly = null, lines = emptyList(), loading = false) },
        onFailure = { mutableState.value.copy(loading = false, error = it.message ?: "Assembly post failed") },
      )
    }
  }
}
