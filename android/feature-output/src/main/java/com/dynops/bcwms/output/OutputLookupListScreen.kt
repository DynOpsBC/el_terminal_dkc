package com.dynops.bcwms.output

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
import com.dynops.bcwms.entity.ProdOrder

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OutputLookupListScreen(
  state: OutputState,
  onRefresh: () -> Unit,
  onOpen: (ProdOrder) -> Unit,
  modifier: Modifier = Modifier,
) {
  Scaffold(
    modifier = modifier.fillMaxSize(),
    topBar = { CenterAlignedTopAppBar(title = { Text("Output") }, actions = { TextButton(onClick = onRefresh) { Text("Refresh") } }) },
  ) { padding ->
    LazyColumn(Modifier.fillMaxSize().padding(padding)) {
      items(state.orders, key = { it.no }) { order ->
        ListItem(
          headlineContent = { Text(order.no) },
          supportingContent = { Text("${order.itemNo}  ${order.description}") },
          overlineContent = { Text(order.status) },
          trailingContent = { Text(order.binCode) },
          modifier = Modifier.clickable { onOpen(order) },
        )
      }
    }
  }
}
