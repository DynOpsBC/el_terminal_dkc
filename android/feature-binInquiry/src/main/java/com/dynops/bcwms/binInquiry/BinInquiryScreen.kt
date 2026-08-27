package com.dynops.bcwms.binInquiry

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun BinInquiryScreen(
  state: BinInquiryState,
  onSearch: (String) -> Unit,
  modifier: Modifier = Modifier,
) {
  var query by remember { mutableStateOf("") }
  Column(modifier = modifier.padding(16.dp)) {
    OutlinedTextField(
      value = query,
      onValueChange = { query = it },
      label = { Text("Bin") },
      modifier = Modifier.fillMaxWidth(),
    )
    Button(onClick = { onSearch(query) }, modifier = Modifier.padding(top = 12.dp)) {
      Text("Search")
    }
    when (state) {
      BinInquiryState.Empty -> Text("No bin selected", modifier = Modifier.padding(top = 16.dp))
      BinInquiryState.Loading -> CircularProgressIndicator(modifier = Modifier.padding(top = 16.dp))
      is BinInquiryState.Error -> Text(state.message, modifier = Modifier.padding(top = 16.dp))
      is BinInquiryState.BinLoaded -> {
        Text(state.bin.code, modifier = Modifier.padding(top = 16.dp))
        Text(state.bin.description)
        BinLpTree(state.bin)
      }
    }
  }
}
