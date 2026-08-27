package com.dynops.bcwms.config

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.dynops.bcwms.core.network.BcApiClient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class DeviceConfigUiState(
  val loading: Boolean = false,
  val deviceId: String = "",
  val configCode: String = "",
  val endpoint: String = "",
  val error: String? = null,
)

class DeviceConfigViewModel(
  private val apiClient: BcApiClient,
) : ViewModel() {
  private val mutableState = MutableStateFlow(DeviceConfigUiState())
  val state: StateFlow<DeviceConfigUiState> = mutableState.asStateFlow()

  fun load(deviceId: String) {
    mutableState.value = mutableState.value.copy(loading = true, error = null)
    viewModelScope.launch {
      mutableState.value = DeviceConfigUiState(
        loading = false,
        deviceId = deviceId,
        configCode = "DEFAULT",
        endpoint = apiClient.deviceConfigUrl(deviceId),
      )
    }
  }
}
