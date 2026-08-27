package com.dynops.bcwms.lp

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
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.dynops.bcwms.entity.LicensePlate
import com.dynops.bcwms.entity.LpLine

@Composable
fun LpDocumentScreen(
  lp: LicensePlate,
  lines: List<LpLine>,
  onBuild: () -> Unit,
  onStop: () -> Unit,
  onTransfer: () -> Unit,
  onPrint: () -> Unit,
  onProperties: () -> Unit,
  modifier: Modifier = Modifier,
) {
  Column(modifier = modifier.fillMaxSize()) {
    Card(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
      Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(lp.no)
        Text("${lp.status}  ${lp.locationCode}/${lp.binCode}")
        Text("Template ${lp.templateCode}")
      }
    }
    LazyColumn(modifier = Modifier.weight(1f)) {
      items(lines, key = { it.lineNo }) { line ->
        ListItem(
          headlineContent = { Text(line.itemNo.ifBlank { line.childLpNo.orEmpty() }) },
          supportingContent = { Text(line.description) },
          trailingContent = { Text("${line.quantity} ${line.unitOfMeasure}") },
        )
      }
    }
    BottomAppBar {
      Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
        FilledTonalButton(onClick = onBuild) { Text("Build") }
        FilledTonalButton(onClick = onStop) { Text("Stop") }
        TextButton(onClick = onTransfer) { Text("Transfer") }
        TextButton(onClick = onPrint) { Text("Print") }
        TextButton(onClick = onProperties) { Text("Properties") }
        TextButton(onClick = {}) { Text("More") }
      }
    }
  }
}
