package com.dynops.bcwms.consume

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.BottomAppBar
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConsumptionBOMScreen(
  state: ConsumeState,
  onClose: () -> Unit,
  onPost: () -> Unit,
  onEnterBin: (String) -> Unit,
  onEnterItem: (String) -> Unit,
  onConsume: (Int, Double) -> Unit,
  onItemInquiry: (String) -> Unit,
  onBinInquiry: (String) -> Unit,
  modifier: Modifier = Modifier,
) {
  var menuOpen by remember { mutableStateOf(false) }
  var bin by remember(state.selectedBin) { mutableStateOf(state.selectedBin) }
  var item by remember { mutableStateOf("") }
  val order = state.selectedOrder

  Scaffold(
    modifier = modifier.fillMaxSize(),
    topBar = {
      CenterAlignedTopAppBar(
        title = { Text(order?.no ?: "Components") },
        actions = {
          TextButton(onClick = { menuOpen = true }) { Text("Menu") }
          DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
            DropdownMenuItem(text = { Text("Close") }, onClick = { menuOpen = false; onClose() })
            DropdownMenuItem(text = { Text("Post") }, onClick = { menuOpen = false; onPost() })
            DropdownMenuItem(text = { Text("Enter Bin") }, onClick = { menuOpen = false; onEnterBin(bin) })
            DropdownMenuItem(text = { Text("Enter Item") }, onClick = { menuOpen = false; onEnterItem(item) })
            DropdownMenuItem(text = { Text("Show Usage") }, onClick = { menuOpen = false })
            DropdownMenuItem(text = { Text("Item Inquiry") }, onClick = { menuOpen = false; onItemInquiry(item) })
            DropdownMenuItem(text = { Text("Bin Inquiry") }, onClick = { menuOpen = false; onBinInquiry(bin) })
          }
        },
      )
    },
    bottomBar = {
      BottomAppBar {
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
          OutlinedTextField(value = bin, onValueChange = { bin = it; onEnterBin(it) }, label = { Text("Bin") }, singleLine = true, modifier = Modifier.weight(1f))
          OutlinedTextField(value = item, onValueChange = { item = it }, label = { Text("Item") }, singleLine = true, modifier = Modifier.weight(1f))
        }
      }
    },
  ) { padding ->
    LazyColumn(Modifier.fillMaxSize().padding(padding)) {
      items(state.components, key = { it.lineNo }) { line ->
        ListItem(
          headlineContent = { Text(line.itemNo) },
          supportingContent = { Text("${line.description}  ${line.remainingQuantity}/${line.quantity} ${line.unitOfMeasureCode}  Bin ${line.binCode}") },
          trailingContent = { FilledTonalButton(onClick = { onConsume(line.lineNo, line.remainingQuantity) }) { Text("Consume") } },
        )
      }
    }
  }
}
