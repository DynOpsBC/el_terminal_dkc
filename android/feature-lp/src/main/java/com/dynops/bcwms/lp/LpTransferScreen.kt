package com.dynops.bcwms.lp

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ListItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.dynops.bcwms.entity.LicensePlate
import com.dynops.bcwms.entity.LpLine

@Composable
fun LpTransferScreen(
  sourceLp: LicensePlate,
  lines: List<LpLine>,
  onTransfer: (targetLpNo: String?, selectedLineQty: Map<Int, Double>) -> Unit,
  modifier: Modifier = Modifier,
) {
  var targetLp by remember { mutableStateOf("") }
  val selected = remember { mutableStateMapOf<Int, Double>() }
  Column(modifier = modifier.fillMaxSize().padding(16.dp)) {
    Text("Source ${sourceLp.no} ${sourceLp.locationCode}/${sourceLp.binCode}")
    OutlinedTextField(value = targetLp, onValueChange = { targetLp = it }, label = { Text("Scan target LP") }, modifier = Modifier.fillMaxWidth())
    LazyColumn(Modifier.weight(1f)) {
      items(lines, key = { it.lineNo }) { line ->
        ListItem(
          headlineContent = { Text(line.itemNo) },
          supportingContent = { Text("${line.quantity} ${line.unitOfMeasure}") },
          trailingContent = {
            Checkbox(
              checked = selected.containsKey(line.lineNo),
              onCheckedChange = { checked ->
                if (checked) selected[line.lineNo] = line.quantity else selected.remove(line.lineNo)
              },
            )
          },
        )
      }
    }
    Button(onClick = { onTransfer(targetLp.ifBlank { null }, selected.toMap()) }, modifier = Modifier.fillMaxWidth()) {
      Text("Transfer")
    }
  }
}
