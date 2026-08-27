package com.dynops.bcwms.printer

import com.dynops.bcwms.entity.LicensePlate
import com.dynops.bcwms.entity.LpLine
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter

data class LpLabelOptions(
  val widthDots: Int = 812,
  val heightDots: Int = 609,
  val includeSsccApplicationIdentifier: Boolean = true,
  val printedAt: OffsetDateTime = OffsetDateTime.now(),
)

class ZplBuilder {
  fun buildLpLabel(
    lp: LicensePlate,
    lines: List<LpLine>,
    options: LpLabelOptions = LpLabelOptions(),
  ): String {
    val ssccValue = if (options.includeSsccApplicationIdentifier && lp.sscc.isNotBlank()) "(00)${lp.sscc}" else lp.sscc
    val itemRows = lines
      .filter { it.childLpNo.isNullOrBlank() }
      .groupBy { it.itemNo }
      .map { (itemNo, itemLines) -> itemNo to itemLines.sumOf { it.quantity } }
      .sortedByDescending { it.second }
      .take(5)

    return buildString {
      appendLine("^XA")
      appendLine("^PW${options.widthDots}")
      appendLine("^LL${options.heightDots}")
      appendLine("^CI28")
      appendText(40, 30, 42, "LP ${lp.no}")
      appendText(40, 82, 28, "Status ${lp.status}")
      appendText(40, 120, 28, "Location ${lp.locationCode}  Bin ${lp.binCode}")
      appendText(40, 158, 24, "Template ${lp.templateCode}")
      appendLine("^FO40,205^GB720,2,2^FS")
      appendText(40, 225, 24, "Item")
      appendText(480, 225, 24, "Qty")
      itemRows.forEachIndexed { index, row ->
        val y = 260 + (index * 35)
        appendText(40, y, 24, row.first)
        appendText(480, y, 24, formatQty(row.second))
      }
      appendLine("^FO40,450^BY3,3,110^BCN,110,Y,N,N^FD$ssccValue^FS")
      appendText(40, 575, 22, "Printed ${options.printedAt.format(DateTimeFormatter.ISO_OFFSET_DATE_TIME)}")
      appendLine("^XZ")
    }
  }

  private fun StringBuilder.appendText(x: Int, y: Int, size: Int, value: String) {
    appendLine("^FO$x,$y^A0N,$size,$size^FD${escape(value)}^FS")
  }

  private fun escape(value: String): String = value.replace("^", " ").replace("~", " ")

  private fun formatQty(value: Double): String =
    if (value % 1.0 == 0.0) value.toLong().toString() else value.toString()
}
