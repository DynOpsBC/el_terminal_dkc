package com.dynops.bcwms.itemInquiry

import com.dynops.bcwms.core.domain.entity.Item
import com.dynops.bcwms.core.network.BcApiClient

class ItemRepository(
  private val apiClient: BcApiClient,
) {
  suspend fun getItem(no: String): Result<Item> = runCatching {
    Item(
      no = no,
      description = apiClient.itemUrl(no),
    )
  }
}
