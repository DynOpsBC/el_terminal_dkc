package com.dynops.bcwms.assembly

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
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
fun AssemblyScreen(
  state: AssemblyState,
  onQuantityChanged: (Double) -> Unit,
  onPost: () -> Unit,
  modifier: Modifier = Modifier,
) {
  var qty by remember(state.assemblyQty) { mutableStateOf(state.assemblyQty.toString()) }
  Scaffold(
    modifier = modifier.fillMaxSize(),
    topBar = { CenterAlignedTopAppBar(title = { Text(state.selectedAssembly?.no ?: "Assembly") }) },
  ) { padding ->
    Column(Modifier.fillMaxSize().padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
      OutlinedTextField(
        value = qty,
        onValueChange = {
          qty = it
          onQuantityChanged(it.toDoubleOrNull() ?: 0.0)
        },
        label = { Text("Assembly qty") },
        modifier = Modifier.fillMaxWidth(),
      )
      LazyColumn(Modifier.weight(1f)) {
        items(state.lines, key = { it.lineNo }) { line ->
          ListItem(
            headlineContent = { Text(line.itemNo) },
            supportingContent = { Text("${line.description}  ${line.consumedQuantity}/${line.quantity} ${line.unitOfMeasureCode}  Bin ${line.binCode}") },
          )
        }
      }
      FilledTonalButton(onClick = onPost, modifier = Modifier.fillMaxWidth()) { Text("Post") }
    }
  }
}
