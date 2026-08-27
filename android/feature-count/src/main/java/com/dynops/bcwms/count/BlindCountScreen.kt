package com.dynops.bcwms.count

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.dynops.bcwms.design.R
import com.dynops.bcwms.domain.CountLine

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BlindCountScreen(
  line: CountLine,
  submitted: Boolean,
  onSubmit: (String, Double) -> Unit,
  modifier: Modifier = Modifier,
) {
  var binCode by remember(line.lineNo) { mutableStateOf(line.binCode) }
  var quantity by remember(line.lineNo) { mutableStateOf("") }
  Scaffold(
    modifier = modifier.fillMaxSize(),
    topBar = { CenterAlignedTopAppBar(title = { Text(stringResource(R.string.count_blind_mode)) }) },
  ) { padding ->
    Column(Modifier.fillMaxSize().padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
      Text("${stringResource(R.string.count_sheet_no)} ${line.sheetNo}")
      Text("${stringResource(R.string.count_item_no)} ${line.itemNo}")
      OutlinedTextField(value = binCode, onValueChange = { binCode = it }, label = { Text(stringResource(R.string.count_bin_code)) })
      OutlinedTextField(value = quantity, onValueChange = { quantity = it }, label = { Text(stringResource(R.string.count_counted_qty)) })
      Button(onClick = { onSubmit(binCode, quantity.toDoubleOrNull() ?: 0.0) }) {
        Text(stringResource(R.string.count_counted_qty))
      }
      if (submitted || line.countedQty1 != null || line.countedQty2 != null || line.countedQty3 != null) {
        Text("${stringResource(R.string.count_system_qty)} ${line.systemQty}")
        Text("${stringResource(R.string.count_variance)} ${line.variance}")
      }
    }
  }
}
