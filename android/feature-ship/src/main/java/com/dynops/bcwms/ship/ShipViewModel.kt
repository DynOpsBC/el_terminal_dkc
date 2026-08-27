package com.dynops.bcwms.ship

import com.dynops.bcwms.domain.Shipment
import com.dynops.bcwms.domain.ShipmentLine
import com.dynops.bcwms.domain.SourceType
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ShipState(
  val header: Shipment? = null,
  val lines: List<ShipmentLine> = emptyList(),
  val shipments: List<Shipment> = emptyList(),
  val sourceType: SourceType = SourceType.Whse,
  val showOpen: Boolean = false,
  val loading: Boolean = false,
  val posting: Boolean = false,
  val error: String? = null,
  val offline: Boolean = false,
)

sealed interface ShipIntent {
  data class LoadList(val sourceType: SourceType, val showOpen: Boolean = false) : ShipIntent
  data class ToggleShowOpen(val enabled: Boolean) : ShipIntent
  data class OpenDocument(val shipment: Shipment) : ShipIntent
  data class ConfirmLine(val lineNo: Int, val qtyToShip: Double, val licensePlateNo: String, val sscc: String? = null) : ShipIntent
  data class Post(val print: Boolean = false) : ShipIntent
  data object ShipAndInvoice : ShipIntent
  data object PostTransfer : ShipIntent
  data object ClearError : ShipIntent
}

sealed interface ShipEffect {
  data class Posted(val documentNo: String) : ShipEffect
  data class Failed(val message: String) : ShipEffect
}

class ShipViewModel(
  private val repository: ShipRepository,
  private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
) {
  private val mutableState = MutableStateFlow(ShipState())
  val state: StateFlow<ShipState> = mutableState.asStateFlow()

  private val mutableEffects = MutableSharedFlow<ShipEffect>()
  val effects: SharedFlow<ShipEffect> = mutableEffects.asSharedFlow()

  fun handle(intent: ShipIntent) {
    when (intent) {
      is ShipIntent.LoadList -> loadList(intent.sourceType, intent.showOpen)
      is ShipIntent.ToggleShowOpen -> loadList(mutableState.value.sourceType, intent.enabled)
      is ShipIntent.OpenDocument -> openDocument(intent.shipment)
      is ShipIntent.ConfirmLine -> confirmLine(intent)
      is ShipIntent.Post -> postWhse(intent.print)
      ShipIntent.ShipAndInvoice -> postSales()
      ShipIntent.PostTransfer -> postTransfer()
      ShipIntent.ClearError -> mutableState.value = mutableState.value.copy(error = null)
    }
  }

  private fun loadList(sourceType: SourceType, showOpen: Boolean) {
    mutableState.value = mutableState.value.copy(sourceType = sourceType, showOpen = showOpen, loading = true, error = null)
    scope.launch {
      mutableState.value = repository.fetchShipments(sourceType, showOpen).fold(
        onSuccess = { mutableState.value.copy(shipments = it, loading = false, header = null, lines = emptyList()) },
        onFailure = { mutableState.value.copy(loading = false, error = it.message ?: "Shipment lookup failed") },
      )
    }
  }

  private fun openDocument(shipment: Shipment) {
    mutableState.value = mutableState.value.copy(header = shipment, sourceType = shipment.sourceType, loading = true, error = null)
    scope.launch {
      mutableState.value = repository.fetchLines(shipment.no, shipment.sourceType).fold(
        onSuccess = { mutableState.value.copy(lines = it, loading = false) },
        onFailure = { mutableState.value.copy(loading = false, error = it.message ?: "Shipment lines failed") },
      )
    }
  }

  private fun confirmLine(intent: ShipIntent.ConfirmLine) {
    val header = mutableState.value.header ?: return
    scope.launch {
      repository.confirmLine(header.no, intent.lineNo, intent.qtyToShip, intent.licensePlateNo, intent.sscc).fold(
        onSuccess = {
          val lines = mutableState.value.lines.map {
            if (it.lineNo == intent.lineNo) it.copy(qtyToShip = intent.qtyToShip, lpNo = intent.licensePlateNo, sscc = intent.sscc.orEmpty()) else it
          }
          mutableState.value = mutableState.value.copy(lines = lines)
        },
        onFailure = { mutableState.value = mutableState.value.copy(error = it.message ?: "Confirm ship line failed") },
      )
    }
  }

  private fun postWhse(print: Boolean) {
    val header = mutableState.value.header ?: return
    post(header.no) { repository.postShipment(header.no, print, false) }
  }

  private fun postSales() {
    val header = mutableState.value.header ?: return
    post(header.no) { repository.postShipAndInvoice(header.no) }
  }

  private fun postTransfer() {
    val header = mutableState.value.header ?: return
    post(header.no) { repository.postTransferShip(header.no) }
  }

  private fun post(documentNo: String, block: suspend () -> Result<Unit>) {
    mutableState.value = mutableState.value.copy(posting = true, error = null)
    scope.launch {
      block().fold(
        onSuccess = {
          mutableState.value = mutableState.value.copy(posting = false, header = null, lines = emptyList())
          mutableEffects.emit(ShipEffect.Posted(documentNo))
        },
        onFailure = {
          val message = it.message ?: "Shipment post failed"
          mutableState.value = mutableState.value.copy(posting = false, error = message)
          mutableEffects.emit(ShipEffect.Failed(message))
        },
      )
    }
  }
}
