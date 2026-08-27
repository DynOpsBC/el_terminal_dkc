package com.dynops.bcwms.home

sealed interface HomeDestination {
  data object ItemInquiry : HomeDestination
  data object BinInquiry : HomeDestination
  data object Config : HomeDestination
  data class Unknown(val menuItem: String) : HomeDestination
}

class MenuRouter {
  fun route(menuItem: String): HomeDestination = when (menuItem.uppercase()) {
    "ITEM-INQUIRY" -> HomeDestination.ItemInquiry
    "BIN-INQUIRY" -> HomeDestination.BinInquiry
    "CONFIG" -> HomeDestination.Config
    else -> HomeDestination.Unknown(menuItem)
  }
}

data class HomeMenuItem(
  val code: String,
  val title: String,
  val sortOrder: Int,
  val visible: Boolean = true,
)
