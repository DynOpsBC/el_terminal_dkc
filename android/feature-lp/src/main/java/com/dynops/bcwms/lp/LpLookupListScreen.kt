package com.dynops.bcwms.lp

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.FilterChip
import androidx.compose.material3.ListItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.dynops.bcwms.entity.LicensePlate
import com.dynops.bcwms.entity.LpStatus

@Composable
fun LpLookupListScreen(
  state: LpState,
  onFilterChanged: (LpListFilter) -> Unit,
  onOpenLp: (String) -> Unit,
  modifier: Modifier = Modifier,
) {
  var search by remember(state.filter.search) { mutableStateOf(state.filter.search) }
  Column(modifier = modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
    OutlinedTextField(
      value = search,
      onValueChange = {
        search = it
        onFilterChanged(state.filter.copy(search = it))
      },
      label = { Text("Search LP") },
      singleLine = true,
      modifier = Modifier.fillMaxWidth(),
    )
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
      FilterChip(selected = state.filter.locationCode.isNotBlank(), onClick = { onFilterChanged(state.filter.copy(locationCode = "BLUE")) }, label = { Text("Location") })
      FilterChip(selected = state.filter.binCode.isNotBlank(), onClick = { onFilterChanged(state.filter.copy(binCode = "PICK")) }, label = { Text("Bin") })
      FilterChip(selected = state.filter.status != null, onClick = { onFilterChanged(state.filter.copy(status = LpStatus.Built)) }, label = { Text("Status") })
      FilterChip(selected = state.filter.templateCode.isNotBlank(), onClick = { onFilterChanged(state.filter.copy(templateCode = "PALLET-EUR")) }, label = { Text("Template") })
    }
    LazyColumn(modifier = Modifier.fillMaxSize()) {
      items(state.list, key = { it.no }) { lp ->
        LpLookupRow(lp = lp, onOpenLp = onOpenLp)
      }
    }
  }
}

@Composable
private fun LpLookupRow(lp: LicensePlate, onOpenLp: (String) -> Unit) {
  ListItem(
    headlineContent = { Text(lp.no) },
    supportingContent = { Text("${lp.status}  ${lp.locationCode}/${lp.binCode}") },
    trailingContent = { Text(lp.builtDateTime.orEmpty()) },
    modifier = Modifier.clickable { onOpenLp(lp.no) },
  )
}
