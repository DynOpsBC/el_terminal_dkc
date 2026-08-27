package com.dynops.bcwms.ship

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ListItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.dynops.bcwms.domain.SourceType

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShipDocumentScreen(
  state: ShipState,
  onPost: (print: Boolean) -> Unit,
  onShipAndInvoice: () -> Unit,
  onPostTransfer: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val header = state.header
  Scaffold(
    modifier = modifier.fillMaxSize(),
    topBar = { CenterAlignedTopAppBar(title = { Text(header?.no ?: "Shipment") }) },
    bottomBar = {
      Row(Modifier.fillMaxWidth().padding(12.dp)) {
        Button(onClick = { onPost(false) }, enabled = header?.sourceType == SourceType.Whse && !state.posting) { Text("Post") }
        Spacer(Modifier.weight(1f))
        Button(onClick = { onPost(true) }, enabled = header?.sourceType == SourceType.Whse && !state.posting) { Text("Print") }
        if (header?.sourceType == SourceType.Sales) {
          Button(onClick = onShipAndInvoice, enabled = !state.posting) { Text("Ship & Invoice") }
        }
        if (header?.sourceType == SourceType.Transfer) {
          Button(onClick = onPostTransfer, enabled = !state.posting) { Text("Post Transfer") }
        }
      }
    },
  ) { padding ->
    Column(Modifier.fillMaxSize().padding(padding)) {
      if (header != null) {
        Card(Modifier.fillMaxWidth().padding(16.dp)) {
          Column(Modifier.padding(16.dp)) {
            Text(header.sourceType.name)
            Text(header.shipTo)
            Text("${header.sourceNo}  ${header.dueDate}")
          }
        }
      }
      LazyColumn(Modifier.fillMaxSize()) {
        items(state.lines, key = { it.lineNo }) { line ->
          ListItem(
            headlineContent = { Text("${line.itemNo}  ${line.qtyToShip}/${line.qtyOutstanding} ${line.uomCode}") },
            supportingContent = { Text("${line.description}  ${line.binCode}") },
            trailingContent = { Text(line.lpNo.ifBlank { line.sscc.ifBlank { "-" } }) },
          )
        }
      }
    }
  }

  if (state.posting) {
    AlertDialog(
      onDismissRequest = {},
      confirmButton = { TextButton(onClick = {}, enabled = false) { Text("Posting") } },
      title = { Text("Posting shipment") },
      text = { CircularProgressIndicator() },
    )
  }
}
