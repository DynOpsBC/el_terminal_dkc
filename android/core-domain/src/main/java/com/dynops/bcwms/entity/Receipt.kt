package com.dynops.bcwms.entity

data class Receipt(
  val no: String,
  val sourceNo: String,
  val sourceType: String,
  val vendorSourceName: String,
  val dueDate: String? = null,
  val assignedUserId: String? = null,
  val locationCode: String = "",
  val percentComplete: Int = 0,
)
