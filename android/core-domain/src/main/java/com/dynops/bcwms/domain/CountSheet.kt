package com.dynops.bcwms.domain

data class CountSheet(
  val id: String,
  val locationCode: String,
  val mode: CountMode,
  val status: String,
  val createdAt: String,
)
