package com.dynops.bcwms.sync

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.dynops.bcwms.usecase.move.AdHocMove
import com.dynops.bcwms.usecase.pick.AssignPickToMe
import com.dynops.bcwms.usecase.pick.ConfirmPickLine
import com.dynops.bcwms.usecase.pick.MarkPickShort
import com.dynops.bcwms.usecase.pick.StartShippingLp
import com.dynops.bcwms.usecase.pick.StopShippingLp
import com.dynops.bcwms.usecase.putaway.ConfirmPutAwayLine
import com.dynops.bcwms.usecase.ship.ConfirmShipLine
import com.dynops.bcwms.usecase.production.Consume
import com.dynops.bcwms.usecase.production.ConsumeRequest
import com.dynops.bcwms.usecase.production.ReportOutput
import com.dynops.bcwms.usecase.production.ReportOutputRequest
import com.dynops.bcwms.usecase.count.RecordCount

class SyncWorker(
  appContext: Context,
  params: WorkerParameters,
) : CoroutineWorker(appContext, params) {
  override suspend fun doWork(): Result = Result.success()

  suspend fun handleOp(op: Op): Result =
    when (op) {
      is Op.BuildLp -> syncBuildLp(op)
      is Op.StopLp -> syncStopLp(op)
      is Op.AddLpLine -> syncAddLpLine(op)
      is Op.RemoveLpLine -> syncRemoveLpLine(op)
      is Op.AssignLp -> syncAssignLp(op)
      is Op.UnbuildLp -> syncUnbuildLp(op)
      is Op.TransferLp -> syncTransferLp(op)
      is Op.PrintLpLabel -> syncPrintLpLabel(op)
      is Op.UsePartialLp -> syncUsePartialLp(op)
      is Op.NestLp -> syncNestLp(op)
      is Op.UnnestLp -> syncUnnestLp(op)
      is Op.ConfirmReceiptLine -> syncConfirmReceiptLine(op)
      is Op.AssignReceipt -> syncAssignReceipt(op)
      is Op.StartReceiptLp -> syncStartReceiptLp(op)
      is Op.StopReceiptLp -> syncStopReceiptLp(op)
      is Op.ConfirmPutAwayLine -> syncConfirmPutAwayLine(op)
      is Op.RegisterPutAway -> Result.failure()
      is Op.AdHocMove -> syncAdHocMove(op)
      is Op.RegisterDirectedMove -> Result.failure()
      is Op.AssignPickToMe -> syncAssignPickToMe(op)
      is Op.ConfirmPickLine -> syncConfirmPickLine(op)
      is Op.StartShippingLp -> syncStartShippingLp(op)
      is Op.StopShippingLp -> syncStopShippingLp(op)
      is Op.MarkPickShort -> syncMarkPickShort(op)
      is Op.RegisterPick -> Result.failure()
      is Op.ConfirmShipLine -> syncConfirmShipLine(op)
      is Op.PostShipment -> Result.failure()
      is Op.PostShipAndInvoice -> Result.failure()
      is Op.PostTransferShip -> Result.failure()
      is Op.Consume -> syncConsume(op)
      is Op.ReportOutput -> syncReportOutput(op)
      is Op.PostAssembly -> Result.failure()
      is Op.RecordCount -> syncRecordCount(op)
      is Op.CreateCountSheet -> Result.failure()
      is Op.PostCountSheet -> Result.failure()
    }

  private suspend fun syncBuildLp(op: Op.BuildLp): Result = Result.success()
  private suspend fun syncStopLp(op: Op.StopLp): Result = Result.success()
  private suspend fun syncAddLpLine(op: Op.AddLpLine): Result = Result.success()
  private suspend fun syncRemoveLpLine(op: Op.RemoveLpLine): Result = Result.success()
  private suspend fun syncAssignLp(op: Op.AssignLp): Result = Result.success()
  private suspend fun syncUnbuildLp(op: Op.UnbuildLp): Result = Result.success()
  private suspend fun syncTransferLp(op: Op.TransferLp): Result = Result.success()
  private suspend fun syncPrintLpLabel(op: Op.PrintLpLabel): Result = Result.success()
  private suspend fun syncUsePartialLp(op: Op.UsePartialLp): Result = Result.success()
  private suspend fun syncNestLp(op: Op.NestLp): Result = Result.success()
  private suspend fun syncUnnestLp(op: Op.UnnestLp): Result = Result.success()
  private suspend fun syncConfirmReceiptLine(op: Op.ConfirmReceiptLine): Result = Result.success()
  private suspend fun syncAssignReceipt(op: Op.AssignReceipt): Result = Result.success()
  private suspend fun syncStartReceiptLp(op: Op.StartReceiptLp): Result = Result.success()
  private suspend fun syncStopReceiptLp(op: Op.StopReceiptLp): Result = Result.success()
  private suspend fun syncConfirmPutAwayLine(op: Op.ConfirmPutAwayLine): Result {
    val useCase = ConfirmPutAwayLine { Result.success(Unit) }
    return useCase(op.docId, op.lineNo, op.qtyToHandle, op.binCode, op.lpNo).fold(
      onSuccess = { Result.success() },
      onFailure = { Result.retry() },
    )
  }
  private suspend fun syncAdHocMove(op: Op.AdHocMove): Result {
    val useCase = AdHocMove { Result.success(Unit) }
    return useCase(op.fromBin, op.toBin, op.itemNo, op.lpNo, op.qty).fold(
      onSuccess = { Result.success() },
      onFailure = { Result.retry() },
    )
  }
  private suspend fun syncAssignPickToMe(op: Op.AssignPickToMe): Result {
    val useCase = AssignPickToMe { Result.success(Unit) }
    return useCase(op.pickNo).fold(onSuccess = { Result.success() }, onFailure = { Result.retry() })
  }
  private suspend fun syncConfirmPickLine(op: Op.ConfirmPickLine): Result {
    val useCase = ConfirmPickLine { _, _, _, _, _ -> Result.success(Unit) }
    return useCase(op.pickNo, op.lineNo, op.qtyToHandle, op.binCode, op.licensePlateNo).fold(
      onSuccess = { Result.success() },
      onFailure = { Result.retry() },
    )
  }
  private suspend fun syncStartShippingLp(op: Op.StartShippingLp): Result {
    val useCase = StartShippingLp { _, _ -> Result.success("LP-OFFLINE") }
    return useCase(op.pickNo, op.templateCode).fold(onSuccess = { Result.success() }, onFailure = { Result.retry() })
  }
  private suspend fun syncStopShippingLp(op: Op.StopShippingLp): Result {
    val useCase = StopShippingLp { _, _, _ -> Result.success("") }
    return useCase(op.pickNo, op.lpNo, op.printLabel).fold(onSuccess = { Result.success() }, onFailure = { Result.retry() })
  }
  private suspend fun syncMarkPickShort(op: Op.MarkPickShort): Result {
    val useCase = MarkPickShort { _, _, _, _ -> Result.success(Unit) }
    return useCase(op.pickNo, op.lineNo, op.qty, op.reasonCode).fold(onSuccess = { Result.success() }, onFailure = { Result.retry() })
  }
  private suspend fun syncConfirmShipLine(op: Op.ConfirmShipLine): Result {
    val useCase = ConfirmShipLine { _, _, _, _, _ -> Result.success(Unit) }
    return useCase(op.shipmentNo, op.lineNo, op.qtyToShip, op.licensePlateNo, op.sscc).fold(
      onSuccess = { Result.success() },
      onFailure = { Result.retry() },
    )
  }
  private suspend fun syncConsume(op: Op.Consume): Result {
    val useCase = Consume { Result.success(Unit) }
    return useCase(ConsumeRequest(op.prodOrderNo, op.componentLineNo, op.itemNo, op.qty, op.lpNo, op.lotNo, op.serialNo, op.binCode)).fold(
      onSuccess = { Result.success() },
      onFailure = { Result.retry() },
    )
  }
  private suspend fun syncReportOutput(op: Op.ReportOutput): Result {
    val useCase = ReportOutput { Result.success(null) }
    return useCase(ReportOutputRequest(op.prodOrderNo, op.routingLineNo, op.outputQty, op.scrapQty, op.runtime, op.newLpTemplate, op.binCode)).fold(
      onSuccess = { Result.success() },
      onFailure = { Result.retry() },
    )
  }
  private suspend fun syncRecordCount(op: Op.RecordCount): Result {
    val useCase = RecordCount { _, _, _, _ -> Result.success(Unit) }
    return useCase(op.sheetNo, op.lineNo, op.slot, op.qty).fold(
      onSuccess = { Result.success() },
      onFailure = { Result.retry() },
    )
  }

  companion object {
    const val EXPEDITED_WORK_NAME = "bcwms-expedited-sync"
  }
}
