package com.dynops.bcwms.entity

data class LpLine(
  val lpNo: String,
  val lineNo: Int,
  val itemNo: String,
  val description: String = "",
  val quantity: Double,
  val unitOfMeasure: String,
  val lotNo: String? = null,
  val serialNo: String? = null,
  val packageNo: String? = null,
  val childLpNo: String? = null,
)
