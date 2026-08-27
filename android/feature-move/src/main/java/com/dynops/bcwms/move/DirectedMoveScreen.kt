package com.dynops.bcwms.move

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.BottomAppBar
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.dynops.bcwms.domain.entity.MoveDoc

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DirectedMoveScreen(
  doc: MoveDoc,
  onRegister: () -> Unit,
  modifier: Modifier = Modifier,
) {
  Scaffold(
    modifier = modifier.fillMaxSize(),
    topBar = { CenterAlignedTopAppBar(title = { Text(doc.id) }) },
    bottomBar = {
      BottomAppBar {
        FilledTonalButton(onClick = onRegister, modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
          Text("Register")
        }
      }
    },
  ) { padding ->
    Column(Modifier.fillMaxSize().padding(padding)) {
      ListItem(
        headlineContent = { Text(doc.itemNo.ifBlank { doc.lpNo }) },
        supportingContent = { Text("${doc.fromBin} to ${doc.toBin}  qty ${doc.qty}") },
        overlineContent = { Text(doc.status) },
      )
    }
  }
}
