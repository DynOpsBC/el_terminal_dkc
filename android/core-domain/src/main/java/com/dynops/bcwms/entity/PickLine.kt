package com.dynops.bcwms.entity

enum class PickActionType { TAKE, PLACE }

data class PickLine(
  val lineNo: Int,
  val itemNo: String,
  val description: String,
  val actionType: PickActionType,
  val binCode: String,
  val quantity: Double,
  val qtyToHandle: Double,
  val qtyHandled: Double = 0.0,
  val licensePlateNo: String = "",
)
