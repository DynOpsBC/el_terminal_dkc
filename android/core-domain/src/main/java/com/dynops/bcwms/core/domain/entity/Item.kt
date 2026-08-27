package com.dynops.bcwms.core.domain.entity

data class Item(
  val no: String,
  val description: String,
  val baseUnitOfMeasure: String = "",
  val defaultLpTemplateCode: String? = null,
  val defaultPrintRuleCode: String? = null,
)
