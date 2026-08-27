package com.dynops.bcwms.lp

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.dynops.bcwms.entity.PartialUseAction

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LpUsePartialBottomSheet(
  onDismiss: () -> Unit,
  onApply: (PartialUseAction, Double) -> Unit,
) {
  var action by remember { mutableStateOf(PartialUseAction.CreateNewLP) }
  var qty by remember { mutableStateOf("") }
  ModalBottomSheet(onDismissRequest = onDismiss) {
    Column(Modifier.padding(16.dp)) {
      partialOptions.forEach { option ->
        Row(Modifier.fillMaxWidth()) {
          RadioButton(selected = action == option.action, onClick = { action = option.action })
          Column(Modifier.padding(top = 10.dp)) {
            Text(option.title)
            Text(option.explanation)
          }
        }
      }
      OutlinedTextField(value = qty, onValueChange = { qty = it }, label = { Text("Quantity") }, modifier = Modifier.fillMaxWidth())
      Button(onClick = { onApply(action, qty.toDoubleOrNull() ?: 0.0) }, modifier = Modifier.fillMaxWidth().padding(top = 12.dp)) {
        Text("Apply")
      }
    }
  }
}

private data class PartialOption(val action: PartialUseAction, val title: String, val explanation: String)

private val partialOptions = listOf(
  PartialOption(PartialUseAction.CreateNewLP, "Create new LP", "Used quantity remains on this LP and excess moves to a new built LP."),
  PartialOption(PartialUseAction.RemoveExcess, "Remove excess", "LP shrinks to used quantity and the excess becomes loose inventory."),
  PartialOption(PartialUseAction.RemoveUsedPortion, "Remove used portion", "Used quantity leaves and the remaining quantity stays built on this LP."),
  PartialOption(PartialUseAction.Unbuild, "Unbuild", "LP is unbuilt while used quantity leaves and the balance is loose."),
)
