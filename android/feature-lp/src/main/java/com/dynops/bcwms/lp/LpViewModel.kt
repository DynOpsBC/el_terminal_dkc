package com.dynops.bcwms.lp

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.dynops.bcwms.entity.AssignedDocType
import com.dynops.bcwms.entity.LicensePlate
import com.dynops.bcwms.entity.LpLine
import com.dynops.bcwms.entity.PartialUseAction
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class LpState(
  val list: List<LicensePlate> = emptyList(),
  val lp: LicensePlate? = null,
  val lines: List<LpLine> = emptyList(),
  val mode: LpMode = LpMode.List,
  val loading: Boolean = false,
  val error: String? = null,
  val offline: Boolean = false,
  val filter: LpListFilter = LpListFilter(),
)

enum class LpMode {
  List,
  Document,
  Build,
  Transfer,
  Properties,
}

sealed interface LpIntent {
  data class LoadList(val filter: LpListFilter = LpListFilter()) : LpIntent
  data class OpenLp(val lpNo: String) : LpIntent
  data class ScanItem(val rawValue: String) : LpIntent
  data class BuildLp(val templateCode: String, val locationCode: String, val binCode: String) : LpIntent
  data class StopLp(val lpNo: String) : LpIntent
  data class TransferLp(val sourceLpNo: String, val targetLpNo: String?, val lineQuantities: Map<Int, Double>) : LpIntent
  data class PartialUse(val lpNo: String, val lineNo: Int, val quantity: Double, val action: PartialUseAction) : LpIntent
  data class PrintLabel(val lpNo: String, val printerId: String? = null) : LpIntent
  data class AssignToDoc(val lpNo: String, val docType: AssignedDocType, val docNo: String) : LpIntent
}

class LpViewModel(
  private val repository: LpRepository,
) : ViewModel() {
  private val mutableState = MutableStateFlow(LpState())
  val state: StateFlow<LpState> = mutableState.asStateFlow()

  fun handle(intent: LpIntent) {
    when (intent) {
      is LpIntent.LoadList -> loadList(intent.filter)
      is LpIntent.OpenLp -> openLp(intent.lpNo)
      is LpIntent.ScanItem -> mutableState.value = mutableState.value.copy(error = null)
      is LpIntent.BuildLp -> buildLp(intent.templateCode, intent.locationCode, intent.binCode)
      is LpIntent.StopLp -> runAction { repository.stopLp(intent.lpNo) }
      is LpIntent.TransferLp -> runAction { repository.transferLp(intent.sourceLpNo, intent.targetLpNo, intent.lineQuantities).map { } }
      is LpIntent.PartialUse -> runAction { repository.partialUse(intent.lpNo, intent.lineNo, intent.quantity, intent.action) }
      is LpIntent.PrintLabel -> runAction { repository.printLabel(intent.lpNo, intent.printerId) }
      is LpIntent.AssignToDoc -> runAction { repository.assignToDoc(intent.lpNo, intent.docType, intent.docNo) }
    }
  }

  private fun loadList(filter: LpListFilter) {
    mutableState.value = mutableState.value.copy(loading = true, error = null, filter = filter)
    viewModelScope.launch {
      mutableState.value = repository.listLicensePlates(filter).fold(
        onSuccess = { mutableState.value.copy(list = it, loading = false, mode = LpMode.List) },
        onFailure = { mutableState.value.copy(loading = false, error = it.message ?: "LP list failed") },
      )
    }
  }

  private fun openLp(lpNo: String) {
    mutableState.value = mutableState.value.copy(loading = true, error = null)
    viewModelScope.launch {
      mutableState.value = repository.openLicensePlate(lpNo).fold(
        onSuccess = { (lp, lines) -> mutableState.value.copy(lp = lp, lines = lines, loading = false, mode = LpMode.Document) },
        onFailure = { mutableState.value.copy(loading = false, error = it.message ?: "LP lookup failed") },
      )
    }
  }

  private fun buildLp(templateCode: String, locationCode: String, binCode: String) {
    mutableState.value = mutableState.value.copy(loading = true, error = null)
    viewModelScope.launch {
      repository.buildLp(templateCode, locationCode, binCode).fold(
        onSuccess = { openLp(it) },
        onFailure = { mutableState.value = mutableState.value.copy(loading = false, error = it.message ?: "Build LP failed") },
      )
    }
  }

  private fun runAction(action: suspend () -> Result<Unit>) {
    mutableState.value = mutableState.value.copy(loading = true, error = null)
    viewModelScope.launch {
      mutableState.value = action().fold(
        onSuccess = { mutableState.value.copy(loading = false) },
        onFailure = { mutableState.value.copy(loading = false, error = it.message ?: "LP action failed") },
      )
    }
  }
}
