package com.dynops.bcwms.binInquiry

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.dynops.bcwms.core.domain.entity.Bin
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

sealed interface BinInquiryState {
  data object Loading : BinInquiryState
  data object Empty : BinInquiryState
  data class BinLoaded(val bin: Bin) : BinInquiryState
  data class Error(val message: String) : BinInquiryState
}

class BinInquiryViewModel(
  private val repository: BinRepository,
) : ViewModel() {
  private val mutableState = MutableStateFlow<BinInquiryState>(BinInquiryState.Empty)
  val state: StateFlow<BinInquiryState> = mutableState.asStateFlow()

  fun load(code: String) {
    mutableState.value = BinInquiryState.Loading
    viewModelScope.launch {
      mutableState.value = repository.getBin(code)
        .fold(
          onSuccess = { BinInquiryState.BinLoaded(it) },
          onFailure = { BinInquiryState.Error(it.message ?: "Bin lookup failed") },
        )
    }
  }
}
