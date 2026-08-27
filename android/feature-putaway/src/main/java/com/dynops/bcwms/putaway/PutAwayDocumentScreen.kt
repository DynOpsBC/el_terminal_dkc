package com.dynops.bcwms.putaway

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.BottomAppBar
import androidx.compose.material3.CenterAlignedTopAppBar
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
import com.dynops.bcwms.domain.entity.PutAwayDoc
import com.dynops.bcwms.domain.entity.PutAwayLine

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PutAwayDocumentScreen(
  doc: PutAwayDoc,
  suggestedBins: Map<Int, String>,
  pendingRegisterDocId: String?,
  onSuggestBin: (Int) -> Unit,
  onLpScanned: (String) -> Unit,
  onConfirmLine: (PutAwayLine, String, String) -> Unit,
  onSplit: () -> Unit,
  onRequestRegister: () -> Unit,
  onConfirmRegister: () -> Unit,
  onCancelRegister: () -> Unit,
  modifier: Modifier = Modifier,
) {
  var lpScan by remember(doc.id) { mutableStateOf("") }
  Scaffold(
    modifier = modifier.fillMaxSize(),
    topBar = {
      CenterAlignedTopAppBar(
        title = { Text(doc.id) },
        actions = { TextButton(onClick = onSplit) { Text("Split") } },
      )
    },
    bottomBar = {
      BottomAppBar {
        FilledTonalButton(onClick = onRequestRegister, modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
          Text("Register")
        }
      }
    },
  ) { padding ->
    Column(Modifier.fillMaxSize().padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
      Text("${doc.locationCode}  ${doc.status}  ${doc.assignedUserId}")
      OutlinedTextField(
        value = lpScan,
        onValueChange = {
          lpScan = it
          if (it.isNotBlank()) onLpScanned(it)
        },
        label = { Text("LP scan") },
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
      )
      LazyColumn(Modifier.weight(1f)) {
        items(doc.lines, key = { it.lineNo }) { line ->
          val suggested = suggestedBins[line.lineNo]
          ListItem(
            headlineContent = { Text(line.itemNo) },
            supportingContent = { Text("Bin ${line.binCode}  Qty ${line.qtyToHandle}  LP ${line.lpNo}") },
            trailingContent = {
              Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                AssistChip(onClick = { onSuggestBin(line.lineNo) }, label = { Text(suggested ?: "Suggest") })
                TextButton(onClick = { onConfirmLine(line, suggested ?: line.binCode, line.lpNo.ifBlank { lpScan }) }) { Text("Confirm") }
              }
            },
          )
        }
      }
    }
  }

  if (pendingRegisterDocId == doc.id) {
    AlertDialog(
      onDismissRequest = onCancelRegister,
      confirmButton = { FilledTonalButton(onClick = onConfirmRegister) { Text("Register") } },
      dismissButton = { TextButton(onClick = onCancelRegister) { Text("Cancel") } },
      title = { Text("Register put-away") },
      text = { Text("Register ${doc.id} with ${doc.lines.size} lines?") },
    )
  }
}
