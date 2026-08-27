package com.dynops.bcwms.printer

enum class PrintChannel {
  None,
  BusinessCentral,
  PrintNode,
}

data class PrintJob(
  val id: String,
  val printerId: String,
  val payload: String,
  val channel: PrintChannel,
)
