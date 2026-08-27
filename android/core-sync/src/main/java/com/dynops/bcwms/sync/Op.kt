package com.dynops.bcwms.sync

import com.dynops.bcwms.entity.AssignedDocType
import com.dynops.bcwms.entity.PartialUseAction
import com.dynops.bcwms.domain.CountMode

sealed class Op {
  data class BuildLp(val templateCode: String, val locationCode: String, val binCode: String) : Op()
  data class StopLp(val lpNo: String, val printLabel: Boolean = false) : Op()
  data class AddLpLine(val lpNo: String, val itemNo: String, val quantity: Double, val unitOfMeasure: String) : Op()
  data class RemoveLpLine(val lpNo: String, val lineNo: Int) : Op()
  data class AssignLp(val lpNo: String, val docType: AssignedDocType, val docNo: String) : Op()
  data class UnbuildLp(val lpNo: String) : Op()
  data class TransferLp(val sourceLpNo: String, val targetLpNo: String?, val lineQuantities: Map<Int, Double>) : Op()
  data class PrintLpLabel(val lpNo: String, val printerId: String? = null, val copies: Int = 1) : Op()
  data class UsePartialLp(val lpNo: String, val lineNo: Int, val quantity: Double, val action: PartialUseAction) : Op()
  data class NestLp(val childLpNo: String, val parentLpNo: String) : Op()
  data class UnnestLp(val childLpNo: String) : Op()
  data class ConfirmReceiptLine(
    val receiptNo: String,
    val lineNo: Int,
    val qtyToReceive: Double,
    val lotNo: String? = null,
    val serialNo: String? = null,
    val expiryDate: String? = null,
    val licensePlateNo: String? = null,
    val binCode: String? = null,
  ) : Op()
  data class AssignReceipt(val receiptNo: String, val userId: String) : Op()
  data class StartReceiptLp(val receiptNo: String, val lpTemplateCode: String? = null) : Op()
  data class StopReceiptLp(val receiptNo: String, val lpNo: String, val printLabel: Boolean = false) : Op()
  data class ConfirmPutAwayLine(val docId: String, val lineNo: Int, val qtyToHandle: Double, val binCode: String, val lpNo: String) : Op()
  // Online-only: standard warehouse activity registration must not be replayed offline after document state changes.
  data class RegisterPutAway(val docId: String) : Op()
  data class AdHocMove(val fromBin: String, val toBin: String, val itemNo: String, val lpNo: String, val qty: Double) : Op()
  // Online-only: directed movement registration must run against the latest Business Central activity state.
  data class RegisterDirectedMove(val docId: String) : Op()
  data class AssignPickToMe(val pickNo: String) : Op()
  data class ConfirmPickLine(val pickNo: String, val lineNo: Int, val qtyToHandle: Double, val binCode: String, val licensePlateNo: String) : Op()
  data class StartShippingLp(val pickNo: String, val templateCode: String? = null) : Op()
  data class StopShippingLp(val pickNo: String, val lpNo: String, val printLabel: Boolean = true) : Op()
  data class MarkPickShort(val pickNo: String, val lineNo: Int, val qty: Double, val reasonCode: String) : Op()
  // Online-only: pick registration posts warehouse entries and must use the latest server state.
  data class RegisterPick(val pickNo: String) : Op()
  data class ConfirmShipLine(val shipmentNo: String, val lineNo: Int, val qtyToShip: Double, val licensePlateNo: String, val sscc: String? = null) : Op()
  // Online-only: shipment posting must run against the latest Business Central document state.
  data class PostShipment(val shipmentNo: String, val print: Boolean = false, val invoice: Boolean = false) : Op()
  // Online-only: sales ship-and-invoice is transactional posting and must not be replayed after order changes.
  data class PostShipAndInvoice(val salesOrderNo: String) : Op()
  // Online-only: transfer shipment posting must use current server availability and status.
  data class PostTransferShip(val transferOrderNo: String) : Op()
  data class Consume(
    val prodOrderNo: String,
    val componentLineNo: Int,
    val itemNo: String,
    val qty: Double,
    val lpNo: String? = null,
    val lotNo: String? = null,
    val serialNo: String? = null,
    val binCode: String? = null,
  ) : Op()
  data class ReportOutput(
    val prodOrderNo: String,
    val routingLineNo: Int,
    val outputQty: Double,
    val scrapQty: Double,
    val runtime: Double,
    val newLpTemplate: String? = null,
    val binCode: String? = null,
  ) : Op()
  // Online-only: assembly posting wraps standard BC posting and must run against current component availability.
  data class PostAssembly(val assemblyNo: String, val quantity: Double) : Op()
  data class RecordCount(val sheetNo: String, val lineNo: Int, val slot: Int, val qty: Double) : Op()
  // Online-only: count sheet creation depends on current BC number series and journal batch state.
  data class CreateCountSheet(val locationCode: String, val mode: CountMode) : Op()
  // Online-only: count posting creates physical inventory journal entries and must run against latest stock.
  data class PostCountSheet(val sheetNo: String) : Op()
}
