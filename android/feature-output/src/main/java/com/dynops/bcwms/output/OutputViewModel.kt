package com.dynops.bcwms.output

import com.dynops.bcwms.entity.ProdOrder
import com.dynops.bcwms.entity.ProdOrderRouting
import com.dynops.bcwms.usecase.production.ReportOutputRequest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class OutputState(
  val orders: List<ProdOrder> = emptyList(),
  val selectedOrder: ProdOrder? = null,
  val routingLines: List<ProdOrderRouting> = emptyList(),
  val selectedRoutingLineNo: Int? = null,
  val outputQty: Double = 0.0,
  val scrapQty: Double = 0.0,
  val runtime: Double = 0.0,
  val newLp: Boolean = false,
  val newLpTemplate: String = "PALLET-EUR",
  val binCode: String = "",
  val createdLpNo: String? = null,
  val loading: Boolean = false,
  val error: String? = null,
)

sealed interface OutputIntent {
  data object LoadOrders : OutputIntent
  data class OpenOrder(val order: ProdOrder) : OutputIntent
  data class SelectOperation(val routingLineNo: Int) : OutputIntent
  data class EditQuantities(val outputQty: Double, val scrapQty: Double, val runtime: Double) : OutputIntent
  data class ToggleNewLp(val enabled: Boolean) : OutputIntent
  data class EditBin(val binCode: String) : OutputIntent
  data class Report(val templateCode: String? = null) : OutputIntent
  data object ClearError : OutputIntent
}

class OutputViewModel(
  private val repository: OutputRepository,
  private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
) {
  private val mutableState = MutableStateFlow(OutputState())
  val state: StateFlow<OutputState> = mutableState.asStateFlow()

  fun handle(intent: OutputIntent) {
    when (intent) {
      OutputIntent.LoadOrders -> loadOrders()
      is OutputIntent.OpenOrder -> openOrder(intent.order)
      is OutputIntent.SelectOperation -> mutableState.value = mutableState.value.copy(selectedRoutingLineNo = intent.routingLineNo)
      is OutputIntent.EditQuantities -> mutableState.value = mutableState.value.copy(outputQty = intent.outputQty, scrapQty = intent.scrapQty, runtime = intent.runtime)
      is OutputIntent.ToggleNewLp -> mutableState.value = mutableState.value.copy(newLp = intent.enabled)
      is OutputIntent.EditBin -> mutableState.value = mutableState.value.copy(binCode = intent.binCode)
      is OutputIntent.Report -> report(intent.templateCode)
      OutputIntent.ClearError -> mutableState.value = mutableState.value.copy(error = null)
    }
  }

  private fun loadOrders() {
    mutableState.value = mutableState.value.copy(loading = true, error = null)
    scope.launch {
      mutableState.value = repository.listReleasedProdOrders().fold(
        onSuccess = { mutableState.value.copy(orders = it, loading = false) },
        onFailure = { mutableState.value.copy(loading = false, error = it.message ?: "Production order lookup failed") },
      )
    }
  }

  private fun openOrder(order: ProdOrder) {
    mutableState.value = mutableState.value.copy(selectedOrder = order, binCode = order.binCode, loading = true, error = null)
    scope.launch {
      mutableState.value = repository.getRoutingLines(order.no).fold(
        onSuccess = { mutableState.value.copy(routingLines = it, selectedRoutingLineNo = it.firstOrNull()?.routingLineNo, loading = false) },
        onFailure = { mutableState.value.copy(loading = false, error = it.message ?: "Routing lookup failed") },
      )
    }
  }

  private fun report(templateCode: String?) {
    val state = mutableState.value
    val order = state.selectedOrder ?: return
    val routingLineNo = state.selectedRoutingLineNo ?: return
    val request = ReportOutputRequest(order.no, routingLineNo, state.outputQty, state.scrapQty, state.runtime, if (state.newLp) templateCode ?: state.newLpTemplate else null, state.binCode)
    mutableState.value = state.copy(loading = true, error = null)
    scope.launch {
      mutableState.value = repository.reportOutput(request).fold(
        onSuccess = { mutableState.value.copy(createdLpNo = it, loading = false) },
        onFailure = { mutableState.value.copy(loading = false, error = it.message ?: "Report output failed") },
      )
    }
  }
}
