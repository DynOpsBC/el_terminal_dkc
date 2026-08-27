package com.dynops.bcwms.ship.di

import com.dynops.bcwms.domain.SourceType
import com.dynops.bcwms.ship.DefaultShipRepository
import com.dynops.bcwms.ship.ShipRepository
import com.dynops.bcwms.ship.ShipViewModel
import com.dynops.bcwms.usecase.ship.ConfirmShipLine
import com.dynops.bcwms.usecase.ship.GetShipments
import com.dynops.bcwms.usecase.ship.PostShipAndInvoice
import com.dynops.bcwms.usecase.ship.PostShipment
import com.dynops.bcwms.usecase.ship.PostTransferShip

object ShipModule {
  fun provideRepository(): ShipRepository = DefaultShipRepository()
  fun provideGetShipments(repository: ShipRepository = provideRepository()): GetShipments =
    GetShipments { sourceType: SourceType, showOpen: Boolean -> repository.fetchShipments(sourceType, showOpen) }
  fun provideConfirmShipLine(repository: ShipRepository = provideRepository()): ConfirmShipLine =
    ConfirmShipLine(repository::confirmLine)
  fun providePostShipment(repository: ShipRepository = provideRepository()): PostShipment =
    PostShipment(repository::postShipment)
  fun providePostShipAndInvoice(repository: ShipRepository = provideRepository()): PostShipAndInvoice =
    PostShipAndInvoice(repository::postShipAndInvoice)
  fun providePostTransferShip(repository: ShipRepository = provideRepository()): PostTransferShip =
    PostTransferShip(repository::postTransferShip)
  fun provideViewModel(repository: ShipRepository = provideRepository()): ShipViewModel = ShipViewModel(repository)
}
