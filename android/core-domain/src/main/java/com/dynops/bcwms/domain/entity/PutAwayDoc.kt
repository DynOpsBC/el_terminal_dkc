package com.dynops.bcwms.domain.entity

data class PutAwayDoc(
  val id: String,
  val locationCode: String,
  val assignedUserId: String,
  val status: String,
  val lines: List<PutAwayLine> = emptyList(),
)
