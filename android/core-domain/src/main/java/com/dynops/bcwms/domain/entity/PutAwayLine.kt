package com.dynops.bcwms.domain.entity

data class PutAwayLine(
  val lineNo: Int,
  val itemNo: String,
  val binCode: String,
  val qtyToHandle: Double,
  val lpNo: String,
  val targetLpNo: String,
)
