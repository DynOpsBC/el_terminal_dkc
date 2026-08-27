package com.dynops.bcwms.entity

data class LpTemplate(
  val code: String,
  val description: String,
  val defaultLengthCm: Double,
  val defaultWidthCm: Double,
  val defaultHeightCm: Double,
  val maxWeightKg: Double,
)
