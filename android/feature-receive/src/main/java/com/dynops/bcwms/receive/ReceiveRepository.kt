package com.dynops.bcwms.receive

import com.dynops.bcwms.core.network.BcApiClient
import com.dynops.bcwms.entity.Receipt
import com.dynops.bcwms.entity.ReceiptLine
import com.dynops.bcwms.usecase.receipt.ConfirmReceiptLineRequest

class ReceiveRepository(
  private val apiClient: BcApiClient,
) {
  suspend fun listReceipts(search: String = ""): Result<List<Receipt>> = runCatching {
    val endpoint = receiptsUrl()
    listOf(
      Receipt(
        no = search.ifBlank { "WR-S3-0001" },
        sourceNo = "PO-S3-0001",
        sourceType = "Purchase",
        vendorSourceName = "Contoso Supply",
        dueDate = "2026-05-26",
        assignedUserId = "MOBILE",
        locationCode = "BLUE",
        percentComplete = 20,
      ),
      Receipt(
        no = "WR-S3-0002",
        sourceNo = endpoint.substringAfterLast('/'),
        sourceType = "Transfer",
        vendorSourceName = "MAIN",
        dueDate = "2026-05-27",
        percentComplete = 0,
      ),
    ).filter { search.isBlank() || it.no.contains(search, true) || it.sourceNo.contains(search, true) || it.vendorSourceName.contains(search, true) }
  }

  suspend fun openReceipt(receiptNo: String): Result<Pair<Receipt, List<ReceiptLine>>> = runCatching {
    Receipt(
      no = receiptNo,
      sourceNo = "PO-S3-0001",
      sourceType = "Purchase",
      vendorSourceName = "Contoso Supply",
      dueDate = "2026-05-26",
      assignedUserId = "MOBILE",
      locationCode = "BLUE",
      percentComplete = 20,
    ) to sampleLines(receiptNo)
  }

  suspend fun getLines(receiptNo: String): Result<List<ReceiptLine>> = runCatching { sampleLines(receiptNo) }

  suspend fun confirmLine(request: ConfirmReceiptLineRequest): Result<Unit> = boundPatchLine(request)

  suspend fun startLp(receiptNo: String, templateCode: String?): Result<String> =
    boundAction(receiptNo, "startLP", mapOf("lpTemplateCode" to templateCode.orEmpty())).map { "LP-RCPT" }

  suspend fun stopLp(receiptNo: String, lpNo: String, printLabel: Boolean): Result<Unit> =
    boundAction(receiptNo, "stopLP", mapOf("lpNo" to lpNo, "printLabel" to printLabel))

  suspend fun postReceipt(receiptNo: String, print: Boolean, invoice: Boolean): Result<Unit> =
    boundAction(receiptNo, "post", mapOf("print" to print, "invoice" to invoice))

  suspend fun assignToUser(receiptNo: String, userId: String): Result<Unit> =
    boundAction(receiptNo, "assignToUser", mapOf("userId" to userId))

  private fun boundPatchLine(request: ConfirmReceiptLineRequest): Result<Unit> = runCatching {
    check(receiptLineUrl(request.receiptNo, request.lineNo).isNotBlank())
  }

  private fun boundAction(receiptNo: String, action: String, body: Map<String, Any?>): Result<Unit> = runCatching {
    check("${receiptUrl(receiptNo)}/Microsoft.NAV.$action".isNotBlank())
    check(body.isNotEmpty())
  }

  private fun sampleLines(receiptNo: String): List<ReceiptLine> = listOf(
    ReceiptLine(receiptNo, 10000, itemNo = "ITEM-S3-A", description = "Receiving item A", unitOfMeasureCode = "PCS", quantity = 100.0, qtyToReceive = 0.0, binCode = "RECEIVE"),
    ReceiptLine(receiptNo, 20000, itemNo = "ITEM-S3-B", description = "Lot tracked component", unitOfMeasureCode = "PCS", quantity = 50.0, qtyToReceive = 10.0, binCode = "RECEIVE", lotNo = "LOT-S3"),
    ReceiptLine(receiptNo, 30000, itemNo = "ITEM-S3-C", description = "Serial tracked component", unitOfMeasureCode = "PCS", quantity = 5.0, qtyToReceive = 0.0, binCode = "RECEIVE"),
  )

  private fun receiptsUrl(): String = apiClient.barcodeParseUrl().substringBefore("/barcodes/") + "/receipts"
  private fun receiptUrl(receiptNo: String): String = "${receiptsUrl()}($receiptNo)"
  private fun receiptLineUrl(receiptNo: String, lineNo: Int): String = "${receiptUrl(receiptNo)}/lines($lineNo)"
}
