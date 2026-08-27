package com.dynops.bcwms.pick

import androidx.compose.foundation.background
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
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.dynops.bcwms.entity.PickActionType
import com.dynops.bcwms.entity.PickDoc

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PickDocumentScreen(
  pick: PickDoc,
  currentLp: String?,
  mode: PickMode,
  onStartLp: () -> Unit,
  onStopLp: () -> Unit,
  onSwitchTakePlace: () -> Unit,
  onRegister: () -> Unit,
  onMarkShort: (Int) -> Unit,
  modifier: Modifier = Modifier,
) {
  Scaffold(
    modifier = modifier.fillMaxSize(),
    topBar = {
      CenterAlignedTopAppBar(
        title = { Text(pick.no) },
        actions = { TextButton(onClick = onSwitchTakePlace) { Text(if (mode == PickMode.TAKE) "Take" else "Place") } },
      )
    },
    bottomBar = {
      BottomAppBar {
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
          FilledTonalButton(onClick = onRegister, modifier = Modifier.weight(1f)) { Text("Register") }
          FilledTonalButton(onClick = { pick.lines.firstOrNull()?.let { onMarkShort(it.lineNo) } }, modifier = Modifier.weight(1f)) { Text("Mark Short") }
        }
      }
    },
  ) { padding ->
    Column(Modifier.fillMaxSize().padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
      Text("${pick.sourceNo}  ${pick.locationCode}  ${pick.status}")
      Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Start LP")
        Switch(checked = currentLp != null, onCheckedChange = { if (it) onStartLp() else onStopLp() })
        Text(currentLp ?: "No LP")
      }
      LazyColumn(Modifier.weight(1f)) {
        items(pick.lines, key = { it.lineNo }) { line ->
          val color = if (line.actionType == PickActionType.TAKE) Color(0xFFEAF3FF) else Color(0xFFEAF8EF)
          ListItem(
            headlineContent = { Text("${line.actionType.name} ${line.itemNo}") },
            supportingContent = { Text("${line.description}  Bin ${line.binCode}  Qty ${line.qtyToHandle}/${line.quantity}  LP ${line.licensePlateNo}") },
            trailingContent = { TextButton(onClick = { onMarkShort(line.lineNo) }) { Text("Short") } },
            modifier = Modifier.fillMaxWidth().background(color),
          )
        }
      }
    }
  }
}
