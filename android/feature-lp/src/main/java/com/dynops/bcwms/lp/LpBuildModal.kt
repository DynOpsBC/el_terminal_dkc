package com.dynops.bcwms.lp

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LpBuildModal(
  onDismiss: () -> Unit,
  onStartBuilding: (templateCode: String, locationCode: String, binCode: String) -> Unit,
) {
  var template by remember { mutableStateOf("CARTON-M") }
  var location by remember { mutableStateOf("") }
  var bin by remember { mutableStateOf("") }
  ModalBottomSheet(onDismissRequest = onDismiss) {
    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
      OutlinedTextField(value = template, onValueChange = { template = it }, label = { Text("Template") }, modifier = Modifier.fillMaxWidth())
      OutlinedTextField(value = location, onValueChange = { location = it }, label = { Text("Scan location") }, modifier = Modifier.fillMaxWidth())
      OutlinedTextField(value = bin, onValueChange = { bin = it }, label = { Text("Scan bin") }, modifier = Modifier.fillMaxWidth())
      Button(onClick = { onStartBuilding(template, location, bin) }, modifier = Modifier.fillMaxWidth()) {
        Text("Start Building")
      }
    }
  }
}
