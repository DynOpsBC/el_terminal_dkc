package com.dynops.bcwms.usecase.ship

import com.dynops.bcwms.domain.Shipment
import com.dynops.bcwms.domain.SourceType

class GetShipments(
  private val executeRequest: suspend (sourceType: SourceType, showOpen: Boolean) -> Result<List<Shipment>>,
) {
  suspend operator fun invoke(sourceType: SourceType = SourceType.Whse, showOpen: Boolean = false): Result<List<Shipment>> =
    executeRequest(sourceType, showOpen)
}
