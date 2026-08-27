package com.dynops.bcwms.entity

data class ReceiptLine(
  val receiptNo: String,
  val lineNo: Int,
  val sourceNo: String = "",
  val sourceLineNo: Int = 0,
  val itemNo: String,
  val description: String,
  val unitOfMeasureCode: String,
  val quantity: Double,
  val qtyToReceive: Double,
  val qtyReceived: Double = 0.0,
  val binCode: String = "",
  val lotNo: String? = null,
  val serialNo: String? = null,
  val expiryDate: String? = null,
  val licensePlateNo: String? = null,
) {
  val isComplete: Boolean get() = qtyReceived >= quantity
}
