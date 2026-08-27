package com.dynops.bcwms.move

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ListItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.dynops.bcwms.domain.entity.MoveDoc

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MoveLookupListScreen(
  selectedTab: Int,
  directedDocs: List<MoveDoc>,
  onSelectAdHoc: () -> Unit,
  onSelectDirected: () -> Unit,
  onOpenDirected: (String) -> Unit,
  modifier: Modifier = Modifier,
) {
  Scaffold(
    modifier = modifier.fillMaxSize(),
    topBar = { CenterAlignedTopAppBar(title = { Text("Movements") }) },
  ) { padding ->
    Column(Modifier.fillMaxSize().padding(padding)) {
      TabRow(selectedTabIndex = selectedTab) {
        Tab(selected = selectedTab == 0, onClick = onSelectAdHoc, text = { Text("AdHoc") })
        Tab(selected = selectedTab == 1, onClick = onSelectDirected, text = { Text("Directed") })
      }
      if (selectedTab == 0) {
        Text("Ad-hoc tab opens the quick move flow.", modifier = Modifier.padding(16.dp))
      } else {
        LazyColumn(Modifier.fillMaxSize()) {
          items(directedDocs, key = { it.id }) { doc ->
            ListItem(
              headlineContent = { Text(doc.id) },
              supportingContent = { Text("${doc.itemNo.ifBlank { doc.lpNo }}  ${doc.fromBin} to ${doc.toBin}") },
              trailingContent = { Text(doc.status) },
              modifier = Modifier.clickable { onOpenDirected(doc.id) },
            )
          }
        }
      }
    }
  }
}
