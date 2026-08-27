package com.dynops.bcwms.putaway

import com.dynops.bcwms.domain.entity.PutAwayDoc
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

sealed interface PutAwayUiState {
  data object Loading : PutAwayUiState
  data class Content(
    val docs: List<PutAwayDoc>,
    val selectedDoc: PutAwayDoc? = null,
    val suggestedBins: Map<Int, String> = emptyMap(),
    val pendingRegisterDocId: String? = null,
  ) : PutAwayUiState
  data class Error(val message: String) : PutAwayUiState
}

sealed interface PutAwayIntent {
  data class Load(val userId: String) : PutAwayIntent
  data class OpenDoc(val docId: String) : PutAwayIntent
  data class SuggestBin(val lineNo: Int) : PutAwayIntent
  data class ScanLp(val lpNo: String) : PutAwayIntent
  data class ConfirmLine(val lineNo: Int, val qtyToHandle: Double, val binCode: String, val lpNo: String) : PutAwayIntent
  data class RequestRegister(val docId: String) : PutAwayIntent
  data class Register(val docId: String) : PutAwayIntent
  data object CancelRegister : PutAwayIntent
}

class PutAwayViewModel(
  private val repository: PutAwayRepository,
  private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
) {
  private val mutableState = MutableStateFlow<PutAwayUiState>(PutAwayUiState.Loading)
  val state: StateFlow<PutAwayUiState> = mutableState.asStateFlow()

  fun handle(intent: PutAwayIntent) {
    when (intent) {
      is PutAwayIntent.Load -> load(intent.userId)
      is PutAwayIntent.OpenDoc -> openDoc(intent.docId)
      is PutAwayIntent.SuggestBin -> suggestBin(intent.lineNo)
      is PutAwayIntent.ScanLp -> applyLpToMatchingLines(intent.lpNo)
      is PutAwayIntent.ConfirmLine -> confirmLine(intent)
      is PutAwayIntent.RequestRegister -> setPendingRegister(intent.docId)
      is PutAwayIntent.Register -> register(intent.docId)
      PutAwayIntent.CancelRegister -> clearPendingRegister()
    }
  }

  private fun load(userId: String) {
    mutableState.value = PutAwayUiState.Loading
    scope.launch {
      mutableState.value = repository.fetchPutAways(userId).fold(
        onSuccess = { PutAwayUiState.Content(it) },
        onFailure = { PutAwayUiState.Error(it.message ?: "Put-away lookup failed") },
      )
    }
  }

  private fun openDoc(docId: String) {
    val content = mutableState.value as? PutAwayUiState.Content ?: return
    mutableState.value = content.copy(selectedDoc = content.docs.firstOrNull { it.id == docId })
  }

  private fun suggestBin(lineNo: Int) {
    val content = mutableState.value as? PutAwayUiState.Content ?: return
    val doc = content.selectedDoc ?: return
    val line = doc.lines.firstOrNull { it.lineNo == lineNo } ?: return
    scope.launch {
      mutableState.value = repository.suggestBin(line.itemNo, line.qtyToHandle, doc.locationCode).fold(
        onSuccess = { content.copy(suggestedBins = content.suggestedBins + (lineNo to it)) },
        onFailure = { PutAwayUiState.Error(it.message ?: "Suggest bin failed") },
      )
    }
  }

  private fun applyLpToMatchingLines(lpNo: String) {
    val content = mutableState.value as? PutAwayUiState.Content ?: return
    val doc = content.selectedDoc ?: return
    val firstItem = doc.lines.firstOrNull()?.itemNo ?: return
    val updatedDoc = doc.copy(lines = doc.lines.map { if (it.itemNo == firstItem || it.lpNo == lpNo || it.lpNo.isBlank()) it.copy(lpNo = lpNo) else it })
    mutableState.value = content.replaceDoc(updatedDoc)
  }

  private fun confirmLine(intent: PutAwayIntent.ConfirmLine) {
    val content = mutableState.value as? PutAwayUiState.Content ?: return
    val doc = content.selectedDoc ?: return
    scope.launch {
      mutableState.value = repository.confirmLine(doc.id, intent.lineNo, intent.qtyToHandle, intent.binCode, intent.lpNo).fold(
        onSuccess = {
          val updatedDoc = doc.copy(lines = doc.lines.map {
            if (it.lineNo == intent.lineNo) it.copy(qtyToHandle = intent.qtyToHandle, binCode = intent.binCode, lpNo = intent.lpNo) else it
          })
          content.replaceDoc(updatedDoc)
        },
        onFailure = { PutAwayUiState.Error(it.message ?: "Confirm put-away line failed") },
      )
    }
  }

  private fun setPendingRegister(docId: String) {
    val content = mutableState.value as? PutAwayUiState.Content ?: return
    mutableState.value = content.copy(pendingRegisterDocId = docId)
  }

  private fun clearPendingRegister() {
    val content = mutableState.value as? PutAwayUiState.Content ?: return
    mutableState.value = content.copy(pendingRegisterDocId = null)
  }

  private fun register(docId: String) {
    val content = mutableState.value as? PutAwayUiState.Content ?: return
    scope.launch {
      mutableState.value = repository.register(docId).fold(
        onSuccess = {
          val updated = content.docs.map { if (it.id == docId) it.copy(status = "Registered") else it }
          content.copy(docs = updated, selectedDoc = updated.firstOrNull { it.id == docId }, pendingRegisterDocId = null)
        },
        onFailure = { PutAwayUiState.Error(it.message ?: "Register put-away failed") },
      )
    }
  }

  private fun PutAwayUiState.Content.replaceDoc(doc: PutAwayDoc): PutAwayUiState.Content {
    val updatedDocs = docs.map { if (it.id == doc.id) doc else it }
    return copy(docs = updatedDocs, selectedDoc = doc)
  }
}
