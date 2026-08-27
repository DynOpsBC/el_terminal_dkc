package com.dynops.bcwms.entity

data class LicensePlate(
  val no: String,
  val status: LpStatus,
  val locationCode: String,
  val binCode: String,
  val templateCode: String,
  val sscc: String = "",
  val parentLpNo: String? = null,
  val assignedDocType: AssignedDocType = AssignedDocType.None,
  val assignedDocNo: String? = null,
  val builtDateTime: String? = null,
  val weightKg: Double? = null,
  val lengthCm: Double? = null,
  val widthCm: Double? = null,
  val heightCm: Double? = null,
  val notes: String = "",
)
