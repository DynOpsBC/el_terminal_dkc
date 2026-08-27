package com.dynops.bcwms.move

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdHocMoveScreen(
  state: MoveUiState.AdHocReady,
  onSourceBin: (String) -> Unit,
  onItemOrLp: (String) -> Unit,
  onTargetBin: (String) -> Unit,
  onQty: (Double) -> Unit,
  onRequestConfirm: () -> Unit,
  onConfirm: () -> Unit,
  onDismissConfirm: () -> Unit,
  modifier: Modifier = Modifier,
) {
  Scaffold(
    modifier = modifier.fillMaxSize(),
    topBar = { CenterAlignedTopAppBar(title = { Text("Ad-hoc move") }) },
  ) { padding ->
    Column(Modifier.fillMaxSize().padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
      OutlinedTextField(state.fromBin, onSourceBin, label = { Text("1 Source bin") }, singleLine = true, modifier = Modifier.fillMaxWidth())
      OutlinedTextField(state.itemOrLp, onItemOrLp, label = { Text("2 Item or LP") }, singleLine = true, modifier = Modifier.fillMaxWidth())
      OutlinedTextField(state.toBin, onTargetBin, label = { Text("3 Target bin") }, singleLine = true, modifier = Modifier.fillMaxWidth())
      OutlinedTextField(state.qty.toString(), { onQty(it.toDoubleOrNull() ?: state.qty) }, label = { Text("Quantity") }, singleLine = true, modifier = Modifier.fillMaxWidth())
      FilledTonalButton(
        onClick = onRequestConfirm,
        enabled = state.fromBin.isNotBlank() && state.itemOrLp.isNotBlank() && state.toBin.isNotBlank() && state.qty > 0,
        modifier = Modifier.fillMaxWidth(),
      ) {
        Text("4 Confirm move")
      }
    }
  }

  if (state.confirmVisible) {
    AlertDialog(
      onDismissRequest = onDismissConfirm,
      confirmButton = { FilledTonalButton(onClick = onConfirm) { Text("Move") } },
      dismissButton = { TextButton(onClick = onDismissConfirm) { Text("Cancel") } },
      title = { Text("Confirm move") },
      text = { Text("${state.itemOrLp} qty ${state.qty} from ${state.fromBin} to ${state.toBin}") },
    )
  }
}
