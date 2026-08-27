package com.dynops.bcwms.core.network

data class BcConnectionProfile(
  val tenantId: String,
  val environmentName: String,
  val companyName: String,
  val companyId: String = companyName,
) {
  val apiBaseUrl: String =
    "https://api.businesscentral.dynamics.com/v2.0/$tenantId/$environmentName/api/v2.0"
  val warehouseApiBaseUrl: String =
    "https://api.businesscentral.dynamics.com/v2.0/$tenantId/$environmentName/api/dynops/warehouse/v2.0/companies($companyId)"
}

class BcApiClient(
  private val profile: BcConnectionProfile,
) {
  fun companiesUrl(): String = "${profile.apiBaseUrl}/companies"
  fun itemUrl(no: String): String = "${profile.warehouseApiBaseUrl}/items($no)"
  fun binUrl(code: String): String = "${profile.warehouseApiBaseUrl}/bins($code)"
  fun deviceConfigUrl(deviceId: String): String = "${profile.warehouseApiBaseUrl}/devices($deviceId)/config"
  fun barcodeParseUrl(): String = "${profile.warehouseApiBaseUrl}/barcodes/Microsoft.NAV.parse"
  fun shipmentsUrl(): String = "${profile.warehouseApiBaseUrl}/shipments"
  fun shipmentLinesUrl(no: String): String = "${profile.warehouseApiBaseUrl}/shipments($no)/lines"
  fun shipmentPostUrl(no: String): String = "${profile.warehouseApiBaseUrl}/shipments($no)/Microsoft.NAV.post"
  fun salesOrdersUrl(): String = "${profile.warehouseApiBaseUrl}/salesOrders"
  fun transferOrdersUrl(): String = "${profile.warehouseApiBaseUrl}/transferOrders"
}
