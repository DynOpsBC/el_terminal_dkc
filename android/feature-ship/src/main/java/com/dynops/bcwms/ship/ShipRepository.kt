package com.dynops.bcwms.ship

import com.dynops.bcwms.domain.Shipment
import com.dynops.bcwms.domain.ShipmentLine
import com.dynops.bcwms.domain.SourceType

interface ShipRepository {
  suspend fun fetchShipments(sourceType: SourceType, showOpen: Boolean): Result<List<Shipment>>
  suspend fun fetchLines(documentNo: String, sourceType: SourceType): Result<List<ShipmentLine>>
  suspend fun confirmLine(documentNo: String, lineNo: Int, qtyToShip: Double, licensePlateNo: String, sscc: String?): Result<Unit>
  suspend fun postShipment(shipmentNo: String, print: Boolean, invoice: Boolean): Result<Unit>
  suspend fun postShipAndInvoice(salesOrderNo: String): Result<Unit>
  suspend fun postTransferShip(transferOrderNo: String): Result<Unit>
}

class DefaultShipRepository : ShipRepository {
  private val whseShipments = mutableListOf(
    Shipment("WS-S6-0001", SourceType.Whse, "SO-1001", "Northwind Retail", "2026-05-28", "MOBILE1", 2, "Released"),
    Shipment("WS-S6-0002", SourceType.Whse, "SO-1002", "Contoso Store 14", "2026-05-29", "", 1, "Released"),
  )
  private val salesOrders = mutableListOf(
    Shipment("SO-S6-0001", SourceType.Sales, "WEB-4481", "Fabrikam Wholesale", "2026-05-28", "", 3, "Ship Pending"),
  )
  private val transferOrders = mutableListOf(
    Shipment("TO-S6-0001", SourceType.Transfer, "BLUE", "Red Warehouse", "2026-05-30", "", 4, "Ship Pending"),
  )
  private val linesByDocument = mutableMapOf(
    "WS-S6-0001" to mutableListOf(
      ShipmentLine(10000, "ITEM-S6-A", "Blue widget", 4.0, 4.0, "LP-S6-01", "", "PCS", "SHIP"),
      ShipmentLine(20000, "ITEM-S6-B", "Packing kit", 1.0, 1.0, "", "", "PCS", "SHIP"),
    ),
    "SO-S6-0001" to mutableListOf(
      ShipmentLine(10000, "ITEM-S6-C", "Direct ship item", 2.0, 2.0, "", "", "PCS", "MAIN"),
    ),
    "TO-S6-0001" to mutableListOf(
      ShipmentLine(10000, "ITEM-S6-D", "Transfer item", 8.0, 8.0, "", "", "PCS", "BULK"),
    ),
  )

  override suspend fun fetchShipments(sourceType: SourceType, showOpen: Boolean): Result<List<Shipment>> = runCatching {
    val docs = when (sourceType) {
      SourceType.Whse -> whseShipments
      SourceType.Sales -> salesOrders
      SourceType.Transfer -> transferOrders
    }
    if (showOpen) docs else docs.filter { it.status == "Released" || it.status == "Ship Pending" }
  }

  override suspend fun fetchLines(documentNo: String, sourceType: SourceType): Result<List<ShipmentLine>> = runCatching {
    linesByDocument[documentNo].orEmpty()
  }

  override suspend fun confirmLine(documentNo: String, lineNo: Int, qtyToShip: Double, licensePlateNo: String, sscc: String?): Result<Unit> = runCatching {
    require(qtyToShip >= 0) { "Quantity to ship cannot be negative" }
    val lines = linesByDocument[documentNo] ?: error("Shipment document not found")
    val index = lines.indexOfFirst { it.lineNo == lineNo }
    require(index >= 0) { "Shipment line not found" }
    lines[index] = lines[index].copy(qtyToShip = qtyToShip, lpNo = licensePlateNo, sscc = sscc.orEmpty())
  }

  override suspend fun postShipment(shipmentNo: String, print: Boolean, invoice: Boolean): Result<Unit> = runCatching {
    whseShipments.removeAll { it.no == shipmentNo }
  }

  override suspend fun postShipAndInvoice(salesOrderNo: String): Result<Unit> = runCatching {
    salesOrders.removeAll { it.no == salesOrderNo }
  }

  override suspend fun postTransferShip(transferOrderNo: String): Result<Unit> = runCatching {
    transferOrders.removeAll { it.no == transferOrderNo }
  }
}
