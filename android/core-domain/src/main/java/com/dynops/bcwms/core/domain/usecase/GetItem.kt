package com.dynops.bcwms.core.domain.usecase

import com.dynops.bcwms.core.domain.entity.Item

fun interface GetItem {
  suspend operator fun invoke(no: String): Result<Item>
}
