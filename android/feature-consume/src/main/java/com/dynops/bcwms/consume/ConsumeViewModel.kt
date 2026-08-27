package com.dynops.bcwms.consume

import com.dynops.bcwms.entity.ProdOrder
import com.dynops.bcwms.entity.ProdOrderComponent
import com.dynops.bcwms.usecase.production.ConsumeRequest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ConsumeState(
  val orders: List<ProdOrder> = emptyList(),
  val selectedOrder: ProdOrder? = null,
  val components: List<ProdOrderComponent> = emptyList(),
  val selectedBin: String = "",
  val loading: Boolean = false,
  val error: String? = null,
)

sealed interface ConsumeIntent {
  data object LoadOrders : ConsumeIntent
  data class OpenOrder(val order: ProdOrder) : ConsumeIntent
  data class EnterBin(val binCode: String) : ConsumeIntent
  data class EnterItem(val itemNo: String) : ConsumeIntent
  data class ScanLp(val lpNo: String, val itemNo: String, val qty: Double) : ConsumeIntent
  data class ConsumeLine(val lineNo: Int, val qty: Double, val lpNo: String? = null, val lotNo: String? = null, val serialNo: String? = null) : ConsumeIntent
  data object Close : ConsumeIntent
  data object Post : ConsumeIntent
  data object ClearError : ConsumeIntent
}

class ConsumeViewModel(
  private val repository: ConsumeRepository,
  private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
) {
  private val mutableState = MutableStateFlow(ConsumeState())
  val state: StateFlow<ConsumeState> = mutableState.asStateFlow()

  fun handle(intent: ConsumeIntent) {
    when (intent) {
      ConsumeIntent.LoadOrders -> loadOrders()
      is ConsumeIntent.OpenOrder -> openOrder(intent.order)
      is ConsumeIntent.EnterBin -> mutableState.value = mutableState.value.copy(selectedBin = intent.binCode)
      is ConsumeIntent.EnterItem -> selectItem(intent.itemNo)
      is ConsumeIntent.ScanLp -> consumeMatchingLp(intent)
      is ConsumeIntent.ConsumeLine -> consumeLine(intent)
      ConsumeIntent.Close -> mutableState.value = ConsumeState(orders = mutableState.value.orders)
      ConsumeIntent.Post -> mutableState.value = mutableState.value.copy(error = null)
      ConsumeIntent.ClearError -> mutableState.value = mutableState.value.copy(error = null)
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
    mutableState.value = mutableState.value.copy(selectedOrder = order, loading = true, error = null)
    scope.launch {
      mutableState.value = repository.getComponents(order.no).fold(
        onSuccess = { mutableState.value.copy(components = it, selectedBin = order.binCode, loading = false) },
        onFailure = { mutableState.value.copy(loading = false, error = it.message ?: "Component lookup failed") },
      )
    }
  }

  private fun selectItem(itemNo: String) {
    val line = mutableState.value.components.firstOrNull { it.itemNo.equals(itemNo, true) } ?: return
    consumeLine(ConsumeIntent.ConsumeLine(line.lineNo, 1.0))
  }

  private fun consumeMatchingLp(intent: ConsumeIntent.ScanLp) {
    val matches = mutableState.value.components.filter { it.itemNo.equals(intent.itemNo, true) && it.remainingQuantity > 0 }
    if (matches.size != 1) {
      mutableState.value = mutableState.value.copy(error = if (matches.isEmpty()) "LP item does not match a component" else "Select a component for this LP item")
      return
    }
    consumeLine(ConsumeIntent.ConsumeLine(matches.first().lineNo, intent.qty, intent.lpNo))
  }

  private fun consumeLine(intent: ConsumeIntent.ConsumeLine) {
    val order = mutableState.value.selectedOrder ?: return
    val line = mutableState.value.components.firstOrNull { it.lineNo == intent.lineNo } ?: return
    val request = ConsumeRequest(order.no, line.lineNo, line.itemNo, intent.qty, intent.lpNo, intent.lotNo, intent.serialNo, mutableState.value.selectedBin.ifBlank { line.binCode })
    mutableState.value = mutableState.value.copy(loading = true, error = null)
    scope.launch {
      mutableState.value = repository.consume(request).fold(
        onSuccess = {
          val updated = mutableState.value.components.map {
            if (it.lineNo == line.lineNo) it.copy(remainingQuantity = (it.remainingQuantity - intent.qty).coerceAtLeast(0.0), lpNo = intent.lpNo, binCode = request.binCode ?: it.binCode) else it
          }
          mutableState.value.copy(components = updated, loading = false)
        },
        onFailure = { mutableState.value.copy(loading = false, error = it.message ?: "Consumption failed") },
      )
    }
  }
}
