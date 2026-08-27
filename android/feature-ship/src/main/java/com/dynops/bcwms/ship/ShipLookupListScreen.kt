package com.dynops.bcwms.ship

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AssistChip
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.ListItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.dynops.bcwms.domain.Shipment
import com.dynops.bcwms.domain.SourceType

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShipLookupListScreen(
  state: ShipState,
  onSourceType: (SourceType) -> Unit,
  onShowOpen: (Boolean) -> Unit,
  onOpen: (Shipment) -> Unit,
  modifier: Modifier = Modifier,
) {
  Scaffold(
    modifier = modifier.fillMaxSize(),
    topBar = { CenterAlignedTopAppBar(title = { Text("Shipping") }) },
  ) { padding ->
    Column(Modifier.fillMaxSize().padding(padding)) {
      Row(Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
        SourceType.entries.forEach { source ->
          FilterChip(
            selected = state.sourceType == source,
            onClick = { onSourceType(source) },
            label = { Text(source.label()) },
          )
          Spacer(Modifier.width(8.dp))
        }
      }
      ListItem(
        headlineContent = { Text("Show Open") },
        trailingContent = { Switch(checked = state.showOpen, onCheckedChange = onShowOpen) },
      )
      LazyColumn(Modifier.fillMaxSize()) {
        items(state.shipments, key = { "${it.sourceType}:${it.no}" }) { shipment ->
          ListItem(
            headlineContent = { Text(shipment.no) },
            supportingContent = { Text("${shipment.sourceNo}  ${shipment.shipTo}  ${shipment.dueDate}") },
            overlineContent = { AssistChip(onClick = {}, label = { Text(shipment.sourceType.label()) }) },
            trailingContent = { Text("${shipment.assignedUser.ifBlank { "-" }} / ${shipment.lineCount}") },
            modifier = Modifier.clickable { onOpen(shipment) },
          )
        }
      }
    }
  }
}

private fun SourceType.label(): String = when (this) {
  SourceType.Whse -> "Whse"
  SourceType.Sales -> "Sales"
  SourceType.Transfer -> "Transfer"
}
