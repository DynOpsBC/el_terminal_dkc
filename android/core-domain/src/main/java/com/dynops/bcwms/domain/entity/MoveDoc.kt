package com.dynops.bcwms.domain.entity

data class MoveDoc(
  val id: String,
  val type: MoveType,
  val fromBin: String,
  val toBin: String,
  val itemNo: String,
  val lpNo: String,
  val qty: Double,
  val status: String,
)

enum class MoveType {
  ADHOC,
  DIRECTED,
}
