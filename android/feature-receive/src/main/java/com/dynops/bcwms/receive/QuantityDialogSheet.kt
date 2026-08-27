package com.dynops.bcwms.receive

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.ModalBottomSheet
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
import com.dynops.bcwms.entity.ReceiptLine

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuantityDialogSheet(
  line: ReceiptLine,
  onDismiss: () -> Unit,
  onConfirm: (quantity: Double, uom: String, lotNo: String?, serialNo: String?, expiryDate: String?) -> Unit,
  modifier: Modifier = Modifier,
) {
  var quantityText by remember(line.lineNo) { mutableStateOf(line.qtyToReceive.toString()) }
  var uom by remember(line.lineNo) { mutableStateOf(line.unitOfMeasureCode) }
  var uomOpen by remember { mutableStateOf(false) }
  var lotNo by remember(line.lineNo) { mutableStateOf(line.lotNo.orEmpty()) }
  var serialNo by remember(line.lineNo) { mutableStateOf(line.serialNo.orEmpty()) }
  var expiryDate by remember(line.lineNo) { mutableStateOf(line.expiryDate.orEmpty()) }

  ModalBottomSheet(onDismissRequest = onDismiss, modifier = modifier) {
    Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
      Text(line.itemNo)
      Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
        TextButton(onClick = { quantityText = ((quantityText.toDoubleOrNull() ?: 0.0) - 1).coerceAtLeast(0.0).toString() }) { Text("-") }
        OutlinedTextField(value = quantityText, onValueChange = { quantityText = it }, label = { Text("Qty") }, modifier = Modifier.weight(1f))
        TextButton(onClick = { quantityText = ((quantityText.toDoubleOrNull() ?: 0.0) + 1).toString() }) { Text("+") }
      }
      TextButton(onClick = { uomOpen = true }) { Text(uom) }
      DropdownMenu(expanded = uomOpen, onDismissRequest = { uomOpen = false }) {
        listOf(line.unitOfMeasureCode, "BOX", "PALLET").distinct().forEach {
          DropdownMenuItem(text = { Text(it) }, onClick = { uom = it; uomOpen = false })
        }
      }
      OutlinedTextField(value = lotNo, onValueChange = { lotNo = it }, label = { Text("Lot") }, modifier = Modifier.fillMaxWidth())
      OutlinedTextField(value = serialNo, onValueChange = { serialNo = it }, label = { Text("Serial") }, modifier = Modifier.fillMaxWidth())
      OutlinedTextField(value = expiryDate, onValueChange = { expiryDate = it }, label = { Text("Expiry") }, modifier = Modifier.fillMaxWidth())
      FilledTonalButton(onClick = { quantityText = ((quantityText.toDoubleOrNull() ?: 0.0) + 1).toString() }, modifier = Modifier.fillMaxWidth()) { Text("+1") }
      Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
        TextButton(onClick = onDismiss) { Text("Cancel") }
        FilledTonalButton(onClick = { onConfirm(quantityText.toDoubleOrNull() ?: 0.0, uom, lotNo.ifBlank { null }, serialNo.ifBlank { null }, expiryDate.ifBlank { null }) }) { Text("Confirm") }
      }
    }
  }
}
