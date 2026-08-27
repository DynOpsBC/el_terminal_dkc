package com.dynops.bcwms.lp

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.dynops.bcwms.entity.LicensePlate

@Composable
fun LpPropertiesScreen(
  lp: LicensePlate,
  onSave: (binCode: String, templateCode: String, weightKg: String, dimensions: Triple<String, String, String>, notes: String) -> Unit,
  modifier: Modifier = Modifier,
) {
  var bin by remember(lp.binCode) { mutableStateOf(lp.binCode) }
  var template by remember(lp.templateCode) { mutableStateOf(lp.templateCode) }
  var weight by remember(lp.weightKg) { mutableStateOf(lp.weightKg?.toString().orEmpty()) }
  var length by remember(lp.lengthCm) { mutableStateOf(lp.lengthCm?.toString().orEmpty()) }
  var width by remember(lp.widthCm) { mutableStateOf(lp.widthCm?.toString().orEmpty()) }
  var height by remember(lp.heightCm) { mutableStateOf(lp.heightCm?.toString().orEmpty()) }
  var notes by remember(lp.notes) { mutableStateOf(lp.notes) }
  Column(modifier = modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
    Text("No. ${lp.no}")
    Text("Status ${lp.status}")
    OutlinedTextField(value = bin, onValueChange = { bin = it }, label = { Text("Bin") }, modifier = Modifier.fillMaxWidth())
    OutlinedTextField(value = template, onValueChange = { template = it }, label = { Text("Template") }, modifier = Modifier.fillMaxWidth())
    OutlinedTextField(value = weight, onValueChange = { weight = it }, label = { Text("Weight kg") }, modifier = Modifier.fillMaxWidth())
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
      OutlinedTextField(value = length, onValueChange = { length = it }, label = { Text("L") }, modifier = Modifier.weight(1f))
      OutlinedTextField(value = width, onValueChange = { width = it }, label = { Text("W") }, modifier = Modifier.weight(1f))
      OutlinedTextField(value = height, onValueChange = { height = it }, label = { Text("H") }, modifier = Modifier.weight(1f))
    }
    OutlinedTextField(value = notes, onValueChange = { notes = it }, label = { Text("Notes") }, modifier = Modifier.fillMaxWidth())
    Button(onClick = { onSave(bin, template, weight, Triple(length, width, height), notes) }, modifier = Modifier.fillMaxWidth()) {
      Text("Save")
    }
  }
}
