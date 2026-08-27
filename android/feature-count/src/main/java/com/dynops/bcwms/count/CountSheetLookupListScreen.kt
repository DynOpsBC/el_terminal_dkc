package com.dynops.bcwms.count

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AssistChip
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ListItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import com.dynops.bcwms.design.R
import com.dynops.bcwms.domain.CountSheet

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CountSheetLookupListScreen(
  sheets: List<CountSheet>,
  onOpen: (String) -> Unit,
  modifier: Modifier = Modifier,
) {
  Scaffold(
    modifier = modifier.fillMaxSize(),
    topBar = { CenterAlignedTopAppBar(title = { Text(stringResource(R.string.count_sheet_title)) }) },
  ) { padding ->
    LazyColumn(contentPadding = padding) {
      items(sheets, key = { it.id }) { sheet ->
        ListItem(
          headlineContent = { Text(sheet.id) },
          supportingContent = { Text("${sheet.locationCode}  ${sheet.mode}") },
          overlineContent = { Text(stringResource(R.string.count_sheet_no)) },
          trailingContent = { AssistChip(onClick = { onOpen(sheet.id) }, label = { Text(sheet.status) }) },
          modifier = Modifier.clickable { onOpen(sheet.id) },
        )
      }
    }
  }
}
