package com.dynops.bcwms.domain

data class CountLine(
  val sheetNo: String,
  val lineNo: Int,
  val itemNo: String,
  val binCode: String,
  val lpNo: String,
  val systemQty: Double,
  val countedQty1: Double?,
  val countedQty2: Double?,
  val countedQty3: Double?,
  val variance: Double,
  val recountRequired: Boolean,
)
