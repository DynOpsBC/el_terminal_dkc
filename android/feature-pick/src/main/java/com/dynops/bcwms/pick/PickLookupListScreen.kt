package com.dynops.bcwms.pick

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AssistChip
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ListItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.dynops.bcwms.entity.PickDoc

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PickLookupListScreen(
  picks: List<PickDoc>,
  assignedToMe: Boolean,
  onAssignedToMeChange: (Boolean) -> Unit,
  onOpen: (String) -> Unit,
  modifier: Modifier = Modifier,
) {
  Scaffold(
    modifier = modifier.fillMaxSize(),
    topBar = { CenterAlignedTopAppBar(title = { Text("Picking") }) },
  ) { padding ->
    Column(Modifier.fillMaxSize().padding(padding)) {
      Row(Modifier.padding(horizontal = 16.dp, vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(if (assignedToMe) "Assigned to Me" else "Show All")
        Switch(checked = !assignedToMe, onCheckedChange = { onAssignedToMeChange(!it) })
      }
      LazyColumn(Modifier.fillMaxSize()) {
        items(picks, key = { it.no }) { pick ->
          ListItem(
            headlineContent = { Text(pick.no) },
            supportingContent = { Text("${pick.sourceNo}  ${pick.locationCode}  ${pick.percentComplete.toInt()}%") },
            overlineContent = { Text(pick.assignedUserId.ifBlank { "Unassigned" }) },
            trailingContent = { AssistChip(onClick = { onOpen(pick.no) }, label = { Text(pick.status) }) },
            modifier = Modifier.clickable { onOpen(pick.no) },
          )
        }
      }
    }
  }
}
