package com.dynops.bcwms.core.domain

data class Company(
  val id: String,
  val name: String,
)

data class ConnectionProfile(
  val tenantId: String,
  val environmentName: String,
  val companyName: String,
  val deviceConfigCode: String = "DEFAULT",
)

