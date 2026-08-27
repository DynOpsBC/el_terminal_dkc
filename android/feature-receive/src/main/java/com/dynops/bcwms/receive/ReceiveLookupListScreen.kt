package com.dynops.bcwms.receive

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ListItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.dynops.bcwms.entity.Receipt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReceiveLookupListScreen(
  state: ReceiveState,
  onSearchChanged: (String) -> Unit,
  onOpenReceipt: (String) -> Unit,
  onRefresh: () -> Unit,
  modifier: Modifier = Modifier,
) {
  var search by remember(state.search) { mutableStateOf(state.search) }
  Column(modifier = modifier.fillMaxSize()) {
    CenterAlignedTopAppBar(
      title = { Text("Receive") },
      actions = {
        TextButton(onClick = onRefresh) { Text("Refresh") }
      },
    )
    Column(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
      OutlinedTextField(
        value = search,
        onValueChange = {
          search = it
          onSearchChanged(it)
        },
        label = { Text("Search document") },
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
      )
      Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        FilterChip(selected = true, onClick = onRefresh, label = { Text("Open") })
        FilterChip(selected = false, onClick = onRefresh, label = { Text("Mine") })
      }
      LazyColumn(modifier = Modifier.fillMaxSize()) {
        items(state.receipts, key = { it.no }) { receipt ->
          ReceiveLookupRow(receipt = receipt, onOpenReceipt = onOpenReceipt)
        }
      }
    }
  }
}

@Composable
private fun ReceiveLookupRow(receipt: Receipt, onOpenReceipt: (String) -> Unit) {
  ListItem(
    headlineContent = { Text(receipt.no) },
    supportingContent = { Text("${receipt.sourceNo}  ${receipt.vendorSourceName}") },
    overlineContent = { Text(receipt.dueDate.orEmpty()) },
    trailingContent = {
      Column {
        Text(receipt.assignedUserId.orEmpty())
        LinearProgressIndicator(progress = { receipt.percentComplete / 100f })
      }
    },
    modifier = Modifier.clickable { onOpenReceipt(receipt.no) },
  )
}
