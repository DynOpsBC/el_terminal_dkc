package com.dynops.bcwms.entity

data class AssemblyLine(
  val assemblyNo: String,
  val lineNo: Int,
  val itemNo: String,
  val description: String = "",
  val quantity: Double,
  val consumedQuantity: Double = 0.0,
  val unitOfMeasureCode: String = "PCS",
  val binCode: String = "",
)
