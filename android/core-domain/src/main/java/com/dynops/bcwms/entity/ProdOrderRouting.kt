package com.dynops.bcwms.entity

data class ProdOrderRouting(
  val prodOrderNo: String,
  val routingLineNo: Int,
  val operationNo: String,
  val workCenterNo: String = "",
  val description: String = "",
  val runtime: Double = 0.0,
  val unitOfMeasureCode: String = "MIN",
)
