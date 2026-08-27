package com.dynops.bcwms.output

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.material3.menuAnchor

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OutputScreen(
  state: OutputState,
  onSelectOperation: (Int) -> Unit,
  onEditQuantities: (Double, Double, Double) -> Unit,
  onToggleNewLp: (Boolean) -> Unit,
  onEditBin: (String) -> Unit,
  onReport: () -> Unit,
  modifier: Modifier = Modifier,
) {
  var expanded by remember { mutableStateOf(false) }
  var output by remember(state.outputQty) { mutableStateOf(state.outputQty.toString()) }
  var scrap by remember(state.scrapQty) { mutableStateOf(state.scrapQty.toString()) }
  var runtime by remember(state.runtime) { mutableStateOf(state.runtime.toString()) }

  Scaffold(
    modifier = modifier.fillMaxSize(),
    topBar = { CenterAlignedTopAppBar(title = { Text(state.selectedOrder?.no ?: "Report Output") }) },
  ) { padding ->
    Column(Modifier.fillMaxSize().padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
      ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
        val selected = state.routingLines.firstOrNull { it.routingLineNo == state.selectedRoutingLineNo }
        OutlinedTextField(
          value = selected?.let { "${it.operationNo} ${it.description}" }.orEmpty(),
          onValueChange = {},
          readOnly = true,
          label = { Text("Operation") },
          trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
          modifier = Modifier.menuAnchor().fillMaxWidth(),
        )
        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
          state.routingLines.forEach { line ->
            DropdownMenuItem(text = { Text("${line.operationNo} ${line.description}") }, onClick = { expanded = false; onSelectOperation(line.routingLineNo) })
          }
        }
      }
      Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        OutlinedTextField(output, { output = it; onEditQuantities(it.toDoubleOrNull() ?: 0.0, scrap.toDoubleOrNull() ?: 0.0, runtime.toDoubleOrNull() ?: 0.0) }, label = { Text("Output") }, modifier = Modifier.weight(1f))
        OutlinedTextField(scrap, { scrap = it; onEditQuantities(output.toDoubleOrNull() ?: 0.0, it.toDoubleOrNull() ?: 0.0, runtime.toDoubleOrNull() ?: 0.0) }, label = { Text("Scrap") }, modifier = Modifier.weight(1f))
      }
      OutlinedTextField(runtime, { runtime = it; onEditQuantities(output.toDoubleOrNull() ?: 0.0, scrap.toDoubleOrNull() ?: 0.0, it.toDoubleOrNull() ?: 0.0) }, label = { Text("Runtime") }, modifier = Modifier.fillMaxWidth())
      OutlinedTextField(state.binCode, onEditBin, label = { Text("Output bin") }, modifier = Modifier.fillMaxWidth())
      Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text("New LP")
        Switch(checked = state.newLp, onCheckedChange = onToggleNewLp)
      }
      state.createdLpNo?.let { Text("LP $it") }
      FilledTonalButton(onClick = onReport, modifier = Modifier.fillMaxWidth()) { Text("Report") }
    }
  }
}
