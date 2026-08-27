package com.dynops.bcwms.binInquiry

import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import com.dynops.bcwms.core.domain.entity.Bin

@Composable
fun BinLpTree(bin: Bin) {
  Column {
    bin.contents.forEach { content ->
      Text("${content.itemNo} ${content.quantity} ${content.unitOfMeasure}")
    }
    // Sprint 2 placeholder: render LP tree once LP API and LP tables are available.
  }
}
