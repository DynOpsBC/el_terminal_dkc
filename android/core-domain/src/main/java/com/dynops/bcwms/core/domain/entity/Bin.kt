package com.dynops.bcwms.core.domain.entity

data class Bin(
  val code: String,
  val locationCode: String,
  val description: String = "",
  val contents: List<BinContent> = emptyList(),
)

data class BinContent(
  val itemNo: String,
  val quantity: Double,
  val unitOfMeasure: String,
)
