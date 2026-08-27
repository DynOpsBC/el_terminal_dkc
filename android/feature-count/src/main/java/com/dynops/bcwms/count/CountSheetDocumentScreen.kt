package com.dynops.bcwms.count

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.BottomAppBar
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.dynops.bcwms.design.R
import com.dynops.bcwms.domain.CountLine
import com.dynops.bcwms.domain.CountSheet

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CountSheetDocumentScreen(
  sheet: CountSheet,
  lines: List<CountLine>,
  onBlindCount: (Int) -> Unit,
  onStartRecount: (Int) -> Unit,
  onPost: () -> Unit,
  modifier: Modifier = Modifier,
) {
  Scaffold(
    modifier = modifier.fillMaxSize(),
    topBar = { CenterAlignedTopAppBar(title = { Text(sheet.id) }) },
    bottomBar = {
      BottomAppBar {
        FilledTonalButton(onClick = onPost, modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
          Text(stringResource(R.string.count_post))
        }
      }
    },
  ) { padding ->
    Column(Modifier.fillMaxSize().padding(padding)) {
      Text("${sheet.locationCode}  ${sheet.mode}  ${sheet.status}", modifier = Modifier.padding(16.dp))
      LazyColumn(Modifier.weight(1f)) {
        items(lines, key = { it.lineNo }) { line ->
          ListItem(
            headlineContent = { Text("${stringResource(R.string.count_item_no)} ${line.itemNo}") },
            supportingContent = {
              Text("${stringResource(R.string.count_bin_code)} ${line.binCode}  ${stringResource(R.string.count_lp_no)} ${line.lpNo}  ${stringResource(R.string.count_variance)} ${line.variance}")
            },
            trailingContent = {
              Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                TextButton(onClick = { onBlindCount(line.lineNo) }) { Text(stringResource(R.string.count_blind_mode)) }
                TextButton(onClick = { onStartRecount(line.lineNo) }) { Text(stringResource(R.string.count_start_recount)) }
              }
            },
          )
        }
      }
    }
  }
}
