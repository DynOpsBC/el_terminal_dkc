package com.dynops.bcwms.pick

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ListItem
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.dynops.bcwms.entity.ShortPickReason

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShortPickDialog(
  reasons: List<ShortPickReason>,
  onDismiss: () -> Unit,
  onSelectReason: (ShortPickReason) -> Unit,
) {
  ModalBottomSheet(onDismissRequest = onDismiss) {
    Column(Modifier.fillMaxWidth().padding(bottom = 24.dp)) {
      Text("Short pick reason", modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp))
      reasons.forEach { reason ->
        ListItem(
          headlineContent = { Text(reason.code) },
          supportingContent = { Text(reason.description) },
          trailingContent = { if (reason.allowsBackorder) Text("Backorder") },
          modifier = Modifier.fillMaxWidth(),
        )
        TextButton(onClick = { onSelectReason(reason) }, modifier = Modifier.fillMaxWidth()) { Text("Use ${reason.code}") }
      }
    }
  }
}
