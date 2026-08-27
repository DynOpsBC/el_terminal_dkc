package com.dynops.bcwms.entity

data class AssemblyOrder(
  val no: String,
  val status: String = "Released",
  val itemNo: String,
  val description: String = "",
  val quantity: Double,
  val remainingQuantity: Double,
  val dueDate: String? = null,
  val locationCode: String = "",
  val binCode: String = "",
  val assembleToOrder: Boolean = false,
)
