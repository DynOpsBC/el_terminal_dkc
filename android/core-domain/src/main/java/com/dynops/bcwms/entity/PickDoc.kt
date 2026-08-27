package com.dynops.bcwms.entity

data class PickDoc(
  val no: String,
  val sourceNo: String,
  val locationCode: String,
  val assignedUserId: String,
  val status: String,
  val dueDate: String? = null,
  val percentComplete: Double = 0.0,
  val lines: List<PickLine> = emptyList(),
)
