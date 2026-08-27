package com.dynops.bcwms.domain

data class Shipment(
  val no: String,
  val sourceType: SourceType,
  val sourceNo: String,
  val shipTo: String,
  val dueDate: String,
  val assignedUser: String,
  val lineCount: Int,
  val status: String,
)
