package com.dynops.bcwms.itemInquiry

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
import com.dynops.bcwms.core.domain.entity.Item

@Composable
fun ItemInquiryScreen(
  state: ItemInquiryState,
  onSearch: (String) -> Unit,
  modifier: Modifier = Modifier,
) {
  var query by remember { mutableStateOf("") }
  Column(modifier = modifier.padding(16.dp)) {
    OutlinedTextField(
      value = query,
      onValueChange = { query = it },
      label = { Text("Item") },
      modifier = Modifier.fillMaxWidth(),
    )
    Button(onClick = { onSearch(query) }, modifier = Modifier.padding(top = 12.dp)) {
      Text("Search")
    }
    when (state) {
      ItemInquiryState.Empty -> Text("No item selected", modifier = Modifier.padding(top = 16.dp))
      ItemInquiryState.Loading -> CircularProgressIndicator(modifier = Modifier.padding(top = 16.dp))
      is ItemInquiryState.Error -> Text(state.message, modifier = Modifier.padding(top = 16.dp))
      is ItemInquiryState.ItemLoaded -> ItemCard(state.item)
    }
  }
}

@Composable
private fun ItemCard(item: Item) {
  Column(modifier = Modifier.padding(top = 16.dp)) {
    Text(item.no)
    Text(item.description)
    Text(item.baseUnitOfMeasure)
  }
}
