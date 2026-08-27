package com.dynops.bcwms.receive

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.dynops.bcwms.entity.Receipt
import com.dynops.bcwms.entity.ReceiptLine
import com.dynops.bcwms.usecase.receipt.ConfirmReceiptLineRequest
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ReceiveState(
  val receipts: List<Receipt> = emptyList(),
  val header: Receipt? = null,
  val lines: List<ReceiptLine> = emptyList(),
  val selectedLp: String? = null,
  val mode: ReceiveMode = ReceiveMode.ScanItem,
  val offline: Boolean = false,
  val loading: Boolean = false,
  val error: String? = null,
  val search: String = "",
)

enum class ReceiveMode { ScanBin, ScanItem, ScanLp }

sealed interface ReceiveIntent {
  data class LoadList(val search: String = "") : ReceiveIntent
  data class OpenDocument(val receiptNo: String) : ReceiveIntent
  data class ScanBarcode(val rawValue: String) : ReceiveIntent
  data class ChangeQty(val lineNo: Int, val quantity: Double, val lotNo: String? = null, val serialNo: String? = null, val expiryDate: String? = null, val binCode: String? = null) : ReceiveIntent
  data class StartLp(val templateCode: String? = null) : ReceiveIntent
  data class StopLp(val printLabel: Boolean = true) : ReceiveIntent
  data class PostDocument(val print: Boolean = false, val invoice: Boolean = false) : ReceiveIntent
  data class AssignToUser(val userId: String) : ReceiveIntent
  data class SetOffline(val offline: Boolean) : ReceiveIntent
  data class SetMode(val mode: ReceiveMode) : ReceiveIntent
}

class ReceiveViewModel(
  private val repository: ReceiveRepository,
) : ViewModel() {
  private val mutableState = MutableStateFlow(ReceiveState())
  val state: StateFlow<ReceiveState> = mutableState.asStateFlow()

  fun handle(intent: ReceiveIntent) {
    when (intent) {
      is ReceiveIntent.LoadList -> loadList(intent.search)
      is ReceiveIntent.OpenDocument -> openDocument(intent.receiptNo)
      is ReceiveIntent.ScanBarcode -> handleScan(intent.rawValue)
      is ReceiveIntent.ChangeQty -> changeQty(intent)
      is ReceiveIntent.StartLp -> startLp(intent.templateCode)
      is ReceiveIntent.StopLp -> stopLp(intent.printLabel)
      is ReceiveIntent.PostDocument -> postDocument(intent.print, intent.invoice)
      is ReceiveIntent.AssignToUser -> assignToUser(intent.userId)
      is ReceiveIntent.SetOffline -> mutableState.value = mutableState.value.copy(offline = intent.offline)
      is ReceiveIntent.SetMode -> mutableState.value = mutableState.value.copy(mode = intent.mode)
    }
  }

  private fun loadList(search: String) {
    mutableState.value = mutableState.value.copy(loading = true, error = null, search = search)
    viewModelScope.launch {
      mutableState.value = repository.listReceipts(search).fold(
        onSuccess = { mutableState.value.copy(receipts = it, loading = false) },
        onFailure = { mutableState.value.copy(loading = false, error = it.message ?: "Receipt list failed") },
      )
    }
  }

  private fun openDocument(receiptNo: String) {
    mutableState.value = mutableState.value.copy(loading = true, error = null)
    viewModelScope.launch {
      mutableState.value = repository.openReceipt(receiptNo).fold(
        onSuccess = { (header, lines) -> mutableState.value.copy(header = header, lines = lines, loading = false) },
        onFailure = { mutableState.value.copy(loading = false, error = it.message ?: "Receipt lookup failed") },
      )
    }
  }

  private fun handleScan(rawValue: String) {
    val line = mutableState.value.lines.firstOrNull { rawValue.contains(it.itemNo, ignoreCase = true) } ?: return
    changeQty(ReceiveIntent.ChangeQty(line.lineNo, line.qtyToReceive + 1.0, line.lotNo, line.serialNo, line.expiryDate, line.binCode))
  }

  private fun changeQty(intent: ReceiveIntent.ChangeQty) {
    val header = mutableState.value.header ?: return
    val selectedLp = mutableState.value.selectedLp
    val request = ConfirmReceiptLineRequest(header.no, intent.lineNo, intent.quantity, intent.lotNo, intent.serialNo, intent.expiryDate, selectedLp, intent.binCode)
    mutableState.value = mutableState.value.copy(loading = true, error = null)
    viewModelScope.launch {
      mutableState.value = repository.confirmLine(request).fold(
        onSuccess = {
          val updated = mutableState.value.lines.map {
            if (it.lineNo == intent.lineNo) it.copy(qtyToReceive = intent.quantity, lotNo = intent.lotNo, serialNo = intent.serialNo, expiryDate = intent.expiryDate, licensePlateNo = selectedLp, binCode = intent.binCode ?: it.binCode) else it
          }
          mutableState.value.copy(lines = updated, loading = false)
        },
        onFailure = { mutableState.value.copy(loading = false, error = it.message ?: "Confirm receipt line failed") },
      )
    }
  }

  private fun startLp(templateCode: String?) {
    val header = mutableState.value.header ?: return
    mutableState.value = mutableState.value.copy(loading = true, error = null)
    viewModelScope.launch {
      mutableState.value = repository.startLp(header.no, templateCode).fold(
        onSuccess = { mutableState.value.copy(selectedLp = it, mode = ReceiveMode.ScanItem, loading = false) },
        onFailure = { mutableState.value.copy(loading = false, error = it.message ?: "Start LP failed") },
      )
    }
  }

  private fun stopLp(printLabel: Boolean) {
    val header = mutableState.value.header ?: return
    val lpNo = mutableState.value.selectedLp ?: return
    runAction { repository.stopLp(header.no, lpNo, printLabel) }
  }

  private fun postDocument(print: Boolean, invoice: Boolean) {
    val header = mutableState.value.header ?: return
    if (mutableState.value.offline) {
      mutableState.value = mutableState.value.copy(error = "Çevrimdışıyken kayıt yapılamaz")
      return
    }
    runAction { repository.postReceipt(header.no, print, invoice) }
  }

  private fun assignToUser(userId: String) {
    val header = mutableState.value.header ?: return
    runAction { repository.assignToUser(header.no, userId) }
  }

  private fun runAction(action: suspend () -> Result<Unit>) {
    mutableState.value = mutableState.value.copy(loading = true, error = null)
    viewModelScope.launch {
      mutableState.value = action().fold(
        onSuccess = { mutableState.value.copy(loading = false) },
        onFailure = { mutableState.value.copy(loading = false, error = it.message ?: "Receive action failed") },
      )
    }
  }
}
