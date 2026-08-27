package com.dynops.bcwms.move

import com.dynops.bcwms.domain.entity.MoveDoc
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

sealed interface MoveUiState {
  data object Loading : MoveUiState
  data class AdHocReady(
    val fromBin: String = "",
    val itemOrLp: String = "",
    val toBin: String = "",
    val qty: Double = 1.0,
    val confirmVisible: Boolean = false,
  ) : MoveUiState
  data class DirectedContent(
    val docs: List<MoveDoc>,
    val selectedDoc: MoveDoc? = null,
  ) : MoveUiState
  data class Error(val message: String) : MoveUiState
}

sealed interface MoveIntent {
  data object LoadAdHoc : MoveIntent
  data class LoadDirected(val type: String? = "DIRECTED") : MoveIntent
  data class ScanSourceBin(val value: String) : MoveIntent
  data class ScanItemOrLp(val value: String) : MoveIntent
  data class ScanTargetBin(val value: String) : MoveIntent
  data class ChangeQty(val qty: Double) : MoveIntent
  data object RequestAdHocConfirm : MoveIntent
  data object ConfirmAdHoc : MoveIntent
  data class OpenDirected(val docId: String) : MoveIntent
  data class RegisterDirected(val docId: String) : MoveIntent
}

class MoveViewModel(
  private val repository: MoveRepository,
  private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
) {
  private val mutableState = MutableStateFlow<MoveUiState>(MoveUiState.AdHocReady())
  val state: StateFlow<MoveUiState> = mutableState.asStateFlow()

  fun handle(intent: MoveIntent) {
    when (intent) {
      MoveIntent.LoadAdHoc -> mutableState.value = MoveUiState.AdHocReady()
      is MoveIntent.LoadDirected -> loadDirected(intent.type)
      is MoveIntent.ScanSourceBin -> mutateAdHoc { it.copy(fromBin = intent.value) }
      is MoveIntent.ScanItemOrLp -> mutateAdHoc { it.copy(itemOrLp = intent.value) }
      is MoveIntent.ScanTargetBin -> mutateAdHoc { it.copy(toBin = intent.value) }
      is MoveIntent.ChangeQty -> mutateAdHoc { it.copy(qty = intent.qty) }
      MoveIntent.RequestAdHocConfirm -> mutateAdHoc { it.copy(confirmVisible = true) }
      MoveIntent.ConfirmAdHoc -> confirmAdHoc()
      is MoveIntent.OpenDirected -> openDirected(intent.docId)
      is MoveIntent.RegisterDirected -> registerDirected(intent.docId)
    }
  }

  private fun loadDirected(type: String?) {
    mutableState.value = MoveUiState.Loading
    scope.launch {
      mutableState.value = repository.fetchMovements(type).fold(
        onSuccess = { MoveUiState.DirectedContent(it) },
        onFailure = { MoveUiState.Error(it.message ?: "Movement lookup failed") },
      )
    }
  }

  private fun mutateAdHoc(transform: (MoveUiState.AdHocReady) -> MoveUiState.AdHocReady) {
    val current = mutableState.value as? MoveUiState.AdHocReady ?: MoveUiState.AdHocReady()
    mutableState.value = transform(current)
  }

  private fun confirmAdHoc() {
    val current = mutableState.value as? MoveUiState.AdHocReady ?: return
    val isLp = current.itemOrLp.startsWith("LP", ignoreCase = true)
    scope.launch {
      mutableState.value = repository.adHocMove(
        fromBin = current.fromBin,
        toBin = current.toBin,
        itemNo = if (isLp) "" else current.itemOrLp,
        lpNo = if (isLp) current.itemOrLp else "",
        qty = current.qty,
      ).fold(
        onSuccess = { MoveUiState.AdHocReady() },
        onFailure = { MoveUiState.Error(it.message ?: "Ad-hoc move failed") },
      )
    }
  }

  private fun openDirected(docId: String) {
    val content = mutableState.value as? MoveUiState.DirectedContent ?: return
    mutableState.value = content.copy(selectedDoc = content.docs.firstOrNull { it.id == docId })
  }

  private fun registerDirected(docId: String) {
    val content = mutableState.value as? MoveUiState.DirectedContent ?: return
    scope.launch {
      mutableState.value = repository.registerDirected(docId).fold(
        onSuccess = {
          val docs = content.docs.map { if (it.id == docId) it.copy(status = "Registered") else it }
          content.copy(docs = docs, selectedDoc = docs.firstOrNull { it.id == docId })
        },
        onFailure = { MoveUiState.Error(it.message ?: "Register directed move failed") },
      )
    }
  }
}
