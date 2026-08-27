package com.dynops.bcwms.putaway

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.dynops.bcwms.domain.entity.PutAwayDoc

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PutAwayLookupListScreen(
  docs: List<PutAwayDoc>,
  currentUserId: String,
  onRefresh: () -> Unit,
  onOpenDocument: (String) -> Unit,
  modifier: Modifier = Modifier,
) {
  Scaffold(
    modifier = modifier.fillMaxSize(),
    topBar = { CenterAlignedTopAppBar(title = { Text("Put-away") }) },
    floatingActionButton = { FloatingActionButton(onClick = onRefresh) { Text("Refresh") } },
  ) { padding ->
    val assignedDocs = docs.filter { it.assignedUserId.equals(currentUserId, ignoreCase = true) || currentUserId.isBlank() }
    Box(Modifier.fillMaxSize().padding(padding)) {
      if (assignedDocs.isEmpty()) {
        Text("No put-away documents", modifier = Modifier.align(Alignment.Center))
      } else {
        LazyColumn(Modifier.fillMaxSize()) {
          items(assignedDocs, key = { it.id }) { doc ->
            ListItem(
              headlineContent = { Text(doc.id) },
              supportingContent = { Text("${doc.locationCode}  ${doc.status}") },
              overlineContent = { Text(doc.assignedUserId) },
              trailingContent = { Text("${doc.lines.size}") },
              modifier = Modifier.clickable { onOpenDocument(doc.id) },
            )
          }
        }
      }
    }
  }
}
