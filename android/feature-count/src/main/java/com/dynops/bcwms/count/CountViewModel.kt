package com.dynops.bcwms.count

import com.dynops.bcwms.domain.CountLine
import com.dynops.bcwms.domain.CountMode
import com.dynops.bcwms.domain.CountSheet
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

sealed interface CountUiState {
  data object Loading : CountUiState
  data class SheetList(val sheets: List<CountSheet>, val locationCode: String) : CountUiState
  data class SheetDetail(val sheet: CountSheet, val lines: List<CountLine>) : CountUiState
  data class BlindCount(val sheet: CountSheet, val line: CountLine, val submitted: Boolean = false) : CountUiState
  data class Error(val message: String) : CountUiState
}

sealed interface CountEvent {
  data class Created(val sheetNo: String) : CountEvent
  data class Posted(val sheetNo: String) : CountEvent
  data class CountRecorded(val sheetNo: String, val lineNo: Int) : CountEvent
}

sealed interface CountIntent {
  data class LoadSheets(val locationCode: String) : CountIntent
  data class OpenSheet(val sheetNo: String) : CountIntent
  data class CreateSheet(val locationCode: String, val mode: CountMode, val counters: List<String>) : CountIntent
  data class OpenBlindCount(val sheetNo: String, val lineNo: Int) : CountIntent
  data class SubmitCount(val sheetNo: String, val lineNo: Int, val slot: Int, val qty: Double) : CountIntent
  data class StartRecount(val sheetNo: String, val lineNo: Int) : CountIntent
  data class PostSheet(val sheetNo: String) : CountIntent
}

class CountViewModel(
  private val repository: CountRepository,
  private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
) {
  private val mutableState = MutableStateFlow<CountUiState>(CountUiState.Loading)
  val state: StateFlow<CountUiState> = mutableState.asStateFlow()
  private val cachedSheets = mutableListOf<CountSheet>()

  fun handle(intent: CountIntent) {
    when (intent) {
      is CountIntent.LoadSheets -> loadSheets(intent.locationCode)
      is CountIntent.OpenSheet -> openSheet(intent.sheetNo)
      is CountIntent.CreateSheet -> createSheet(intent)
      is CountIntent.OpenBlindCount -> openBlindCount(intent.sheetNo, intent.lineNo)
      is CountIntent.SubmitCount -> submitCount(intent)
      is CountIntent.StartRecount -> startRecount(intent.sheetNo, intent.lineNo)
      is CountIntent.PostSheet -> postSheet(intent.sheetNo)
    }
  }

  private fun loadSheets(locationCode: String) {
    mutableState.value = CountUiState.Loading
    scope.launch {
      mutableState.value = repository.getSheets(locationCode).fold(
        onSuccess = {
          cachedSheets.clear()
          cachedSheets += it
          CountUiState.SheetList(it, locationCode)
        },
        onFailure = { CountUiState.Error(it.message ?: "Count sheet lookup failed") },
      )
    }
  }

  private fun openSheet(sheetNo: String) {
    val sheet = cachedSheets.firstOrNull { it.id == sheetNo } ?: return
    scope.launch {
      mutableState.value = repository.getLines(sheetNo).fold(
        onSuccess = { CountUiState.SheetDetail(sheet, it) },
        onFailure = { CountUiState.Error(it.message ?: "Count sheet detail failed") },
      )
    }
  }

  private fun createSheet(intent: CountIntent.CreateSheet) {
    scope.launch {
      repository.createSheet(intent.locationCode, intent.mode, intent.counters).onSuccess {
        loadSheets(intent.locationCode)
      }.onFailure {
        mutableState.value = CountUiState.Error(it.message ?: "Create count sheet failed")
      }
    }
  }

  private fun openBlindCount(sheetNo: String, lineNo: Int) {
    val sheet = cachedSheets.firstOrNull { it.id == sheetNo } ?: return
    scope.launch {
      val line = repository.getLines(sheetNo).getOrDefault(emptyList()).firstOrNull { it.lineNo == lineNo }
      mutableState.value = line?.let { CountUiState.BlindCount(sheet, it) } ?: CountUiState.Error("Count line not found")
    }
  }

  private fun submitCount(intent: CountIntent.SubmitCount) {
    scope.launch {
      repository.recordCount(intent.sheetNo, intent.lineNo, intent.slot, intent.qty).fold(
        onSuccess = { openBlindCount(intent.sheetNo, intent.lineNo) },
        onFailure = { mutableState.value = CountUiState.Error(it.message ?: "Record count failed") },
      )
    }
  }

  private fun startRecount(sheetNo: String, lineNo: Int) {
    scope.launch { repository.startRecount(sheetNo, lineNo).onSuccess { openSheet(sheetNo) } }
  }

  private fun postSheet(sheetNo: String) {
    scope.launch { repository.postSheet(sheetNo).onSuccess { loadSheets(cachedSheets.firstOrNull { it.id == sheetNo }?.locationCode.orEmpty()) } }
  }
}
