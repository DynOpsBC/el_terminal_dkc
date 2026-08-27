package com.dynops.bcwms.core.domain.usecase

import com.dynops.bcwms.core.domain.entity.Bin

fun interface GetBin {
  suspend operator fun invoke(code: String): Result<Bin>
}
