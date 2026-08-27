package com.dynops.bcwms.feature.auth

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun ConnectionProfileScreen(
  profile: ConnectionProfileUiState = ConnectionProfileUiState(),
  onTenantChanged: (String) -> Unit = {},
  onEnvironmentChanged: (String) -> Unit = {},
  onCompanyChanged: (String) -> Unit = {},
  onDeviceConfigChanged: (String) -> Unit = {},
  onImportQr: () -> Unit = {},
) {
  Column(modifier = Modifier.padding(24.dp)) {
    OutlinedTextField(value = profile.tenantId, onValueChange = onTenantChanged, label = { Text("Tenant") })
    OutlinedTextField(value = profile.environmentName, onValueChange = onEnvironmentChanged, label = { Text("Environment") })
    OutlinedTextField(value = profile.companyName, onValueChange = onCompanyChanged, label = { Text("Company") })
    OutlinedTextField(value = profile.deviceConfigCode, onValueChange = onDeviceConfigChanged, label = { Text("Device Config") })
    Button(onClick = onImportQr, modifier = Modifier.padding(top = 12.dp)) {
      Text("Import QR")
    }
  }
}
