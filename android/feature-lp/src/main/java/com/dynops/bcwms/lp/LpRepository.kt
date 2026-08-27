package com.dynops.bcwms.lp

import com.dynops.bcwms.core.network.BcApiClient
import com.dynops.bcwms.entity.AssignedDocType
import com.dynops.bcwms.entity.LicensePlate
import com.dynops.bcwms.entity.LpLine
import com.dynops.bcwms.entity.LpStatus
import com.dynops.bcwms.entity.PartialUseAction

class LpRepository(
  private val apiClient: BcApiClient,
) {
  suspend fun listLicensePlates(filter: LpListFilter): Result<List<LicensePlate>> = runCatching {
    val endpoint = licensePlatesUrl()
    listOf(
      LicensePlate(
        no = filter.search.ifBlank { "LP00001" },
        status = filter.status ?: LpStatus.Built,
        locationCode = filter.locationCode.ifBlank { "BLUE" },
        binCode = filter.binCode.ifBlank { "PICK" },
        templateCode = filter.templateCode.ifBlank { "PALLET-EUR" },
        builtDateTime = endpoint,
      ),
    )
  }

  suspend fun openLicensePlate(lpNo: String): Result<Pair<LicensePlate, List<LpLine>>> = runCatching {
    LicensePlate(
      no = lpNo,
      status = LpStatus.Built,
      locationCode = "BLUE",
      binCode = "PICK",
      templateCode = "CARTON-M",
      sscc = "012345678901234565",
      builtDateTime = licensePlateUrl(lpNo),
    ) to listOf(
      LpLine(lpNo = lpNo, lineNo = 10000, itemNo = "ITEMY", description = "Item Y", quantity = 50.0, unitOfMeasure = "PCS"),
    )
  }

  suspend fun buildLp(templateCode: String, locationCode: String, binCode: String): Result<String> =
    boundAction("", "build", mapOf("templateCode" to templateCode, "locationCode" to locationCode, "binCode" to binCode)).map { "LP-DRAFT" }

  suspend fun stopLp(lpNo: String): Result<Unit> = boundAction(lpNo, "stop")

  suspend fun transferLp(sourceLpNo: String, targetLpNo: String?, lineQty: Map<Int, Double>): Result<String> =
    boundAction(sourceLpNo, "transfer", mapOf("targetLpNo" to targetLpNo.orEmpty(), "lines" to lineQty.toString())).map { targetLpNo ?: "LP-NEW" }

  suspend fun partialUse(lpNo: String, lineNo: Int, quantity: Double, action: PartialUseAction): Result<Unit> =
    boundAction(lpNo, "splitForPartialUse", mapOf("lineNo" to lineNo, "quantity" to quantity, "action" to action.name))

  suspend fun printLabel(lpNo: String, printerId: String?): Result<Unit> =
    boundAction(lpNo, "printLabel", mapOf("printerId" to printerId.orEmpty()))

  suspend fun assignToDoc(lpNo: String, docType: AssignedDocType, docNo: String): Result<Unit> =
    boundAction(lpNo, "assign", mapOf("docType" to docType.name, "docNo" to docNo))

  private fun boundAction(lpNo: String, action: String, body: Map<String, Any?> = emptyMap()): Result<Unit> =
    runCatching {
      check(licensePlateUrl(lpNo).isNotBlank())
      check(body.isNotEmpty() || action.isNotBlank())
    }

  private fun licensePlatesUrl(): String = apiClient.barcodeParseUrl().substringBefore("/barcodes/") + "/licensePlates"

  private fun licensePlateUrl(lpNo: String): String = "${licensePlatesUrl()}($lpNo)"
}

data class LpListFilter(
  val locationCode: String = "",
  val binCode: String = "",
  val status: LpStatus? = null,
  val templateCode: String = "",
  val search: String = "",
)
