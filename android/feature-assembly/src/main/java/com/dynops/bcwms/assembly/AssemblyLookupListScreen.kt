package com.dynops.bcwms.assembly

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ListItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.dynops.bcwms.entity.AssemblyOrder

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AssemblyLookupListScreen(
  state: AssemblyState,
  onRefresh: () -> Unit,
  onOpen: (AssemblyOrder) -> Unit,
  modifier: Modifier = Modifier,
) {
  Scaffold(
    modifier = modifier.fillMaxSize(),
    topBar = { CenterAlignedTopAppBar(title = { Text("Assembly") }, actions = { TextButton(onClick = onRefresh) { Text("Refresh") } }) },
  ) { padding ->
    LazyColumn(Modifier.fillMaxSize().padding(padding)) {
      items(state.assemblies, key = { it.no }) { assembly ->
        ListItem(
          headlineContent = { Text(assembly.no) },
          supportingContent = { Text("${assembly.itemNo}  ${assembly.description}") },
          overlineContent = { Text(if (assembly.assembleToOrder) "Assemble-to-Order" else "Assemble-to-Stock") },
          trailingContent = { Text("${assembly.remainingQuantity}") },
          modifier = Modifier.clickable { onOpen(assembly) },
        )
      }
    }
  }
}
