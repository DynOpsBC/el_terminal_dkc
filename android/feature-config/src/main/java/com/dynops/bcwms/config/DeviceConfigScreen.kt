package com.dynops.bcwms.config

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun DeviceConfigScreen(
  state: DeviceConfigUiState,
  modifier: Modifier = Modifier,
) {
  Column(modifier = modifier.padding(16.dp)) {
    if (state.loading) {
      CircularProgressIndicator()
    } else {
      Text(state.deviceId)
      Text(state.configCode)
      Text(state.endpoint)
      state.error?.let { Text(it) }
    }
  }
}
