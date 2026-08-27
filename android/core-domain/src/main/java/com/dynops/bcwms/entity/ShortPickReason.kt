package com.dynops.bcwms.entity

data class ShortPickReason(
  val code: String,
  val description: String,
  val isDefault: Boolean = false,
  val allowsBackorder: Boolean = false,
)
