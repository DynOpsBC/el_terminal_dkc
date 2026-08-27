package com.dynops.bcwms.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.json.JSONObject

/**
 * Birleştirilmiş satır kartları — ELOG ziyareti müşteri isteği: bin kodu ve
 * ürün numarası aynı olan satırlar terminalde TEK satır görünsün, miktar
 * toplam gelsin. Karta dokununca üst modül miktar isteyip [distributeQty]
 * ile alt satırlara dağıtır. [staged] o satırda halihazırda girilen miktarı
 * verir (receipt: qtyToReceive, pick: qtyToHandle) — kart yeşili buna bakar.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LineGroupCards(
    groups: List<LineGroup>,
    staged: (JSONObject) -> Double,
    modifier: Modifier = Modifier,
    emptyText: String = "Grup yok.",
    showEmpty: Boolean = true,
    expandRows: Boolean = false,
    onGroupClick: (LineGroup) -> Unit,
) {
    @Composable
    fun GroupCard(g: LineGroup) {
            val stagedSum = g.lines.sumOf { staged(it) }
            val done = stagedSum > 0
            Card(onClick = { onGroupClick(g) }, modifier = Modifier.fillMaxWidth(), colors = doneCardColors(done)) {
                Column(Modifier.padding(14.dp)) {
                    Text("${donePrefix(done)}${g.itemNo} — ${g.description}", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                    Text(
                        buildList {
                            if (g.binCode.isNotBlank()) add("Bin ${g.binCode}")
                            add("${g.count} satır")
                            add("Kalan: ${fmtGrp(g.totalOutstanding)}")
                            if (stagedSum > 0) add("Girilen: ${fmtGrp(stagedSum)}")
                        }.joinToString(" · "),
                        fontSize = 12.sp,
                        color = Color.Gray,
                    )
                }
            }
    }
    if (expandRows) {
        Column(modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            groups.forEach { g -> GroupCard(g) }
            if (groups.isEmpty() && showEmpty) EmptyState(emptyText)
        }
    } else {
        LazyColumn(modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            items(groups) { g -> GroupCard(g) }
            if (groups.isEmpty() && showEmpty) item { EmptyState(emptyText) }
        }
    }
}

/** Pick satırının kalan (dağıtılabilir) kapasitesi — qtyOutstanding, yoksa quantity−qtyHandled. */
fun pickLineCapacity(l: JSONObject): Double {
    val out = l.optDouble("qtyOutstanding", Double.NaN)
    if (!out.isNaN()) return out.coerceAtLeast(0.0)
    return (l.optDouble("quantity", 0.0) - l.optDouble("qtyHandled", 0.0)).coerceAtLeast(0.0)
}

private fun fmtGrp(v: Double): String = if (v == v.toLong().toDouble()) v.toLong().toString() else v.toString()
