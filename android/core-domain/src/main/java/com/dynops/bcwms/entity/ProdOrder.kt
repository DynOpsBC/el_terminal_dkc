package com.dynops.bcwms.entity

data class ProdOrder(
  val no: String,
  val status: String = "Released",
  val itemNo: String,
  val description: String = "",
  val quantity: Double,
  val dueDate: String? = null,
  val locationCode: String = "",
  val binCode: String = "",
)
