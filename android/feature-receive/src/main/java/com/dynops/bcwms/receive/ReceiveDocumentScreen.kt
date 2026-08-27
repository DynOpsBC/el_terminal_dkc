package com.dynops.bcwms.receive

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.BottomAppBar
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TooltipBox
import androidx.compose.material3.TooltipDefaults
import androidx.compose.material3.rememberTooltipState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.dynops.bcwms.entity.Receipt
import com.dynops.bcwms.entity.ReceiptLine

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReceiveDocumentScreen(
  header: Receipt,
  lines: List<ReceiptLine>,
  selectedLp: String?,
  offline: Boolean,
  onPost: () -> Unit,
  onPrint: () -> Unit,
  onStartStopLp: () -> Unit,
  onLineSelected: (ReceiptLine) -> Unit,
  modifier: Modifier = Modifier,
) {
  Column(modifier = modifier.fillMaxSize()) {
    Card(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
      Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(header.no)
        Text("${header.sourceType} ${header.sourceNo}")
        Text("${header.vendorSourceName}  ${header.dueDate.orEmpty()}")
        Text("Assigned ${header.assignedUserId.orEmpty()}  LP ${selectedLp.orEmpty()}")
      }
    }
    LazyColumn(modifier = Modifier.weight(1f)) {
      items(lines, key = { it.lineNo }) { line ->
        ListItem(
          headlineContent = { Text("${line.itemNo}  ${line.description}") },
          supportingContent = { Text("Bin ${line.binCode}  Lot ${line.lotNo.orEmpty()}  LP ${line.licensePlateNo.orEmpty()}") },
          trailingContent = { Text("${line.qtyToReceive}/${line.quantity} ${line.unitOfMeasureCode}") },
          modifier = Modifier.padding(horizontal = 8.dp).fillMaxWidth().clickableNoRipple { onLineSelected(line) },
        )
      }
    }
    BottomAppBar {
      Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
        PostButton(offline = offline, onPost = onPost)
        TextButton(onClick = onPrint) { Text("Print") }
        FilledTonalButton(onClick = onStartStopLp) { Text(if (selectedLp == null) "Start LP" else "Stop LP") }
        TextButton(onClick = {}) { Text("More") }
      }
    }
  }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PostButton(offline: Boolean, onPost: () -> Unit) {
  TooltipBox(
    positionProvider = TooltipDefaults.rememberPlainTooltipPositionProvider(),
    tooltip = { Text("Çevrimdışıyken kayıt yapılamaz") },
    state = rememberTooltipState(),
  ) {
    FilledTonalButton(onClick = onPost, enabled = !offline) { Text("Post") }
  }
}

private fun Modifier.clickableNoRipple(onClick: () -> Unit): Modifier =
  androidx.compose.foundation.clickable(onClick = onClick)
