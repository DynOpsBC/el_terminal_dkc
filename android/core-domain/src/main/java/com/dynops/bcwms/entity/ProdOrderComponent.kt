package com.dynops.bcwms.entity

data class ProdOrderComponent(
  val prodOrderNo: String,
  val lineNo: Int,
  val itemNo: String,
  val description: String = "",
  val quantity: Double,
  val remainingQuantity: Double,
  val unitOfMeasureCode: String = "PCS",
  val locationCode: String = "",
  val binCode: String = "",
  val lpNo: String? = null,
  val lotNo: String? = null,
  val serialNo: String? = null,
)
