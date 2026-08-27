package com.dynops.bcwms.usecase.ship

class PostTransferShip(
  private val executeRequest: suspend (transferOrderNo: String) -> Result<Unit>,
) {
  suspend operator fun invoke(transferOrderNo: String): Result<Unit> = executeRequest(transferOrderNo)
}
