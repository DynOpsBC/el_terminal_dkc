package com.dynops.bcwms.home

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun HomeScreen(
  menuItems: List<HomeMenuItem>,
  onMenuItemClick: (HomeDestination) -> Unit,
  modifier: Modifier = Modifier,
  router: MenuRouter = MenuRouter(),
) {
  Column(modifier = modifier.padding(16.dp)) {
    menuItems.filter { it.visible }.sortedBy { it.sortOrder }.forEach { item ->
      Button(
        onClick = { onMenuItemClick(router.route(item.code)) },
        modifier = Modifier
          .fillMaxWidth()
          .padding(bottom = 8.dp),
      ) {
        Text(item.title)
      }
    }
  }
}
