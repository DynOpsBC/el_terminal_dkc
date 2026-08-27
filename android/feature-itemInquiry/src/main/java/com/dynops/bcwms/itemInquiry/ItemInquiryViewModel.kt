package com.dynops.bcwms.itemInquiry

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.dynops.bcwms.core.domain.entity.Item
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

sealed interface ItemInquiryState {
  data object Loading : ItemInquiryState
  data object Empty : ItemInquiryState
  data class ItemLoaded(val item: Item) : ItemInquiryState
  data class Error(val message: String) : ItemInquiryState
}

sealed interface ItemInquiryIntent {
  data class Load(val itemNo: String) : ItemInquiryIntent
  data object Clear : ItemInquiryIntent
}

class ItemInquiryViewModel(
  private val repository: ItemRepository,
) : ViewModel() {
  private val mutableState = MutableStateFlow<ItemInquiryState>(ItemInquiryState.Empty)
  val state: StateFlow<ItemInquiryState> = mutableState.asStateFlow()

  fun handle(intent: ItemInquiryIntent) {
    when (intent) {
      ItemInquiryIntent.Clear -> mutableState.value = ItemInquiryState.Empty
      is ItemInquiryIntent.Load -> load(intent.itemNo)
    }
  }

  private fun load(itemNo: String) {
    mutableState.value = ItemInquiryState.Loading
    viewModelScope.launch {
      mutableState.value = repository.getItem(itemNo)
        .fold(
          onSuccess = { ItemInquiryState.ItemLoaded(it) },
          onFailure = { ItemInquiryState.Error(it.message ?: "Item lookup failed") },
        )
    }
  }
}
