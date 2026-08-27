package com.dynops.bcwms.pick

import com.dynops.bcwms.entity.PickActionType
import com.dynops.bcwms.entity.PickDoc
import com.dynops.bcwms.entity.ShortPickReason
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

enum class PickMode { TAKE, PLACE }

data class PickState(
  val picks: List<PickDoc> = emptyList(),
  val header: PickDoc? = null,
  val currentLp: String? = null,
  val mode: PickMode = PickMode.TAKE,
  val offline: Boolean = false,
  val assignedToMe: Boolean = true,
  val reasons: List<ShortPickReason> = emptyList(),
  val error: String? = null,
)

sealed interface PickIntent {
  data class LoadList(val assignedToMe: Boolean = true) : PickIntent
  data class Open(val pickNo: String) : PickIntent
  data class AssignToMe(val pickNo: String) : PickIntent
  data class ScanItem(val value: String) : PickIntent
  data class StartLp(val pickNo: String, val templateCode: String? = null) : PickIntent
  data class StopLp(val pickNo: String) : PickIntent
  data class MarkShort(val pickNo: String, val lineNo: Int, val qty: Double, val reasonCode: String) : PickIntent
  data class Register(val pickNo: String) : PickIntent
  data object SwitchTakePlace : PickIntent
}

class PickViewModel(
  private val repository: PickRepository,
  private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
) {
  private val mutableState = MutableStateFlow(PickState())
  val state: StateFlow<PickState> = mutableState.asStateFlow()

  fun handle(intent: PickIntent) {
    when (intent) {
      is PickIntent.LoadList -> loadList(intent.assignedToMe)
      is PickIntent.Open -> open(intent.pickNo)
      is PickIntent.AssignToMe -> assignToMe(intent.pickNo)
      is PickIntent.ScanItem -> confirmScannedItem(intent.value)
      is PickIntent.StartLp -> startLp(intent.pickNo, intent.templateCode)
      is PickIntent.StopLp -> stopLp(intent.pickNo)
      is PickIntent.MarkShort -> markShort(intent)
      is PickIntent.Register -> register(intent.pickNo)
      PickIntent.SwitchTakePlace -> switchTakePlace()
    }
  }

  private fun loadList(assignedToMe: Boolean) {
    scope.launch {
      val reasons = repository.shortPickReasons().getOrDefault(emptyList())
      mutableState.value = repository.fetchPicks(assignedToMe).fold(
        onSuccess = { PickState(picks = it, assignedToMe = assignedToMe, reasons = reasons) },
        onFailure = { mutableState.value.copy(error = it.message ?: "Pick lookup failed") },
      )
    }
  }

  private fun open(pickNo: String) {
    val current = mutableState.value
    mutableState.value = current.copy(header = current.picks.firstOrNull { it.no == pickNo }, error = null)
  }

  private fun assignToMe(pickNo: String) {
    scope.launch { mutateAfter(repository.assignToMe(pickNo)) { it.copy(assignedUserId = "MOBILE", status = "InProgress") } }
  }

  private fun startLp(pickNo: String, templateCode: String?) {
    scope.launch {
      mutableState.value = repository.startShippingLp(pickNo, templateCode).fold(
        onSuccess = { mutableState.value.copy(currentLp = it, error = null) },
        onFailure = { mutableState.value.copy(error = it.message ?: "Start LP failed") },
      )
    }
  }

  private fun stopLp(pickNo: String) {
    val lp = mutableState.value.currentLp ?: return
    scope.launch {
      mutableState.value = repository.stopShippingLp(pickNo, lp).fold(
        onSuccess = { mutableState.value.copy(currentLp = null, error = null) },
        onFailure = { mutableState.value.copy(error = it.message ?: "Stop LP failed") },
      )
    }
  }

  private fun confirmScannedItem(value: String) {
    val current = mutableState.value
    val doc = current.header ?: return
    val line = doc.lines.firstOrNull { it.itemNo.equals(value, ignoreCase = true) && it.actionType.name == current.mode.name } ?: return
    val lp = current.currentLp.orEmpty()
    scope.launch {
      repository.confirmLine(doc.no, line.lineNo, line.qtyToHandle, line.binCode, lp)
      val updated = doc.copy(lines = doc.lines.map { if (it.lineNo == line.lineNo) it.copy(licensePlateNo = lp) else it })
      mutableState.value = current.replaceDoc(updated)
    }
  }

  private fun markShort(intent: PickIntent.MarkShort) {
    scope.launch {
      mutableState.value = repository.markShort(intent.pickNo, intent.lineNo, intent.qty, intent.reasonCode).fold(
        onSuccess = {
          val doc = mutableState.value.header ?: return@fold mutableState.value
          mutableState.value.replaceDoc(doc.copy(lines = doc.lines.map { if (it.lineNo == intent.lineNo) it.copy(qtyToHandle = intent.qty) else it }))
        },
        onFailure = { mutableState.value.copy(error = it.message ?: "Mark short failed") },
      )
    }
  }

  private fun register(pickNo: String) {
    scope.launch { mutateAfter(repository.register(pickNo)) { it.copy(status = "Done", percentComplete = 100.0) } }
  }

  private fun switchTakePlace() {
    val next = if (mutableState.value.mode == PickMode.TAKE) PickMode.PLACE else PickMode.TAKE
    mutableState.value = mutableState.value.copy(mode = next)
  }

  private suspend fun mutateAfter(result: Result<Unit>, transform: (PickDoc) -> PickDoc) {
    mutableState.value = result.fold(
      onSuccess = {
        val doc = mutableState.value.header ?: return@fold mutableState.value
        mutableState.value.replaceDoc(transform(doc))
      },
      onFailure = { mutableState.value.copy(error = it.message ?: "Pick action failed") },
    )
  }

  private fun PickState.replaceDoc(doc: PickDoc): PickState {
    val updated = picks.map { if (it.no == doc.no) doc else it }
    return copy(picks = updated, header = doc, error = null)
  }
}
