package com.dynops.bcwms.domain

data class ShipmentLine(
  val lineNo: Int,
  val itemNo: String,
  val description: String,
  val qtyOutstanding: Double,
  val qtyToShip: Double,
  val lpNo: String,
  val sscc: String,
  val uomCode: String,
  val binCode: String,
)
