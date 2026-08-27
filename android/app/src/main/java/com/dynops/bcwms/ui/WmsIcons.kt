package com.dynops.bcwms.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.dynops.bcwms.Screen

/**
 * BCWMS'in elle çizilmiş ikon ailesi. Bütün şekiller aynı 32x32 optik alanda,
 * aynı yuvarlak uçlu çizgi ve tek vurgu rengiyle çizilir. Böylece terminalin
 * Android/emoji sürümünden bağımsız, tutarlı ve keskin görünürler.
 */
enum class WmsGlyph {
    RECEIVING,
    PUT_AWAY,
    PICKING,
    PACKING,
    SHIPPING,
    LICENSE_PLATE,
    HIERARCHY,
    AD_HOC,
    DIRECTED_MOVE,
    COUNT,
    COUNT_V2,
    PRODUCTION,
    ASSEMBLY,
    QUALITY,
    QUALITY_MANAGEMENT,
    ITEM_SEARCH,
    BIN_SEARCH,
    ENTRIES,
    FIELD_SETTINGS,
    HEALTH,
    PRINTER,
    TEST,
    POSTING,
    CONNECTION,
    HELP,
    WARNING,
    SCAN,
    REFRESH,
    CLOSE,
    CHEVRON,
    LAYOUT,
}

fun glyphForScreen(screen: Screen): WmsGlyph = when (screen) {
    Screen.Receiving -> WmsGlyph.RECEIVING
    Screen.PutAway -> WmsGlyph.PUT_AWAY
    Screen.Picking -> WmsGlyph.PICKING
    Screen.Packing -> WmsGlyph.PACKING
    Screen.Shipping -> WmsGlyph.SHIPPING
    Screen.LicensePlates -> WmsGlyph.LICENSE_PLATE
    Screen.HierarchicalLP -> WmsGlyph.HIERARCHY
    Screen.AdHocMove -> WmsGlyph.AD_HOC
    Screen.DirectedMove -> WmsGlyph.DIRECTED_MOVE
    Screen.Count -> WmsGlyph.COUNT
    Screen.CountV2 -> WmsGlyph.COUNT_V2
    Screen.Production -> WmsGlyph.PRODUCTION
    Screen.Assembly -> WmsGlyph.ASSEMBLY
    Screen.Quality -> WmsGlyph.QUALITY
    Screen.QualityMgmt -> WmsGlyph.QUALITY_MANAGEMENT
    Screen.ItemInquiry -> WmsGlyph.ITEM_SEARCH
    Screen.BinInquiry -> WmsGlyph.BIN_SEARCH
    Screen.WhseEntries -> WmsGlyph.ENTRIES
    Screen.FieldSettings -> WmsGlyph.FIELD_SETTINGS
    Screen.SelfTest -> WmsGlyph.HEALTH
    Screen.Printers -> WmsGlyph.PRINTER
    Screen.TestCenter -> WmsGlyph.TEST
    Screen.PostingTest -> WmsGlyph.POSTING
    Screen.Connection -> WmsGlyph.CONNECTION
    Screen.Help -> WmsGlyph.HELP
    Screen.Home -> WmsGlyph.LAYOUT
}

@Composable
fun WmsIconBadge(
    glyph: WmsGlyph,
    color: Color,
    modifier: Modifier = Modifier,
    size: Dp = 48.dp,
    iconSize: Dp = 27.dp,
) {
    Box(
        modifier
            .size(size)
            .clip(RoundedCornerShape(size * 0.31f))
            .background(color.copy(alpha = 0.12f)),
        contentAlignment = Alignment.Center,
    ) {
        WmsIcon(glyph = glyph, color = color, modifier = Modifier.size(iconSize))
    }
}

/** Ortak buton etiketi; emoji yerine aynı çizgi ikonunu ve metni hizalar. */
@Composable
fun WmsActionLabel(
    glyph: WmsGlyph,
    text: String,
    modifier: Modifier = Modifier,
    color: Color = LocalContentColor.current,
) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically) {
        WmsIcon(glyph, color, Modifier.size(19.dp))
        Spacer(Modifier.width(7.dp))
        Text(text, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.labelLarge)
    }
}

@Composable
fun WmsTabLabel(glyph: WmsGlyph, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        WmsIcon(glyph, LocalContentColor.current, Modifier.size(17.dp))
        Spacer(Modifier.width(6.dp))
        Text(text, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold, maxLines = 1)
    }
}

@Composable
fun WmsRefreshLabel(loading: Boolean, compact: Boolean = false) {
    if (loading) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
            if (!compact) {
                Spacer(Modifier.width(7.dp))
                Text("Yenileniyor...", fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.labelLarge)
            }
        }
    } else if (compact) {
        WmsIcon(WmsGlyph.REFRESH, LocalContentColor.current, Modifier.size(20.dp))
    } else {
        WmsActionLabel(WmsGlyph.REFRESH, "Yenile")
    }
}

@Composable
fun WmsIcon(
    glyph: WmsGlyph,
    color: Color,
    modifier: Modifier = Modifier,
) {
    Canvas(modifier) {
        val s = size.minDimension
        val dx = (size.width - s) / 2f
        val dy = (size.height - s) / 2f
        fun p(x: Float, y: Float) = Offset(dx + s * x, dy + s * y)
        val strokeWidth = s * 0.068f
        val lineStroke = Stroke(strokeWidth, cap = StrokeCap.Round, join = StrokeJoin.Round)
        val thin = Stroke(strokeWidth * 0.72f, cap = StrokeCap.Round, join = StrokeJoin.Round)
        val soft = color.copy(alpha = 0.17f)
        fun line(x1: Float, y1: Float, x2: Float, y2: Float) =
            drawLine(color, p(x1, y1), p(x2, y2), strokeWidth, StrokeCap.Round)
        fun thinLine(x1: Float, y1: Float, x2: Float, y2: Float) =
            drawLine(color, p(x1, y1), p(x2, y2), strokeWidth * 0.72f, StrokeCap.Round)
        fun roundRect(x: Float, y: Float, w: Float, h: Float, fill: Boolean = false) {
            drawRoundRect(
                color = if (fill) soft else color,
                topLeft = p(x, y),
                size = Size(s * w, s * h),
                cornerRadius = CornerRadius(s * 0.07f),
                style = if (fill) androidx.compose.ui.graphics.drawscope.Fill else lineStroke,
            )
        }
        fun arrowDown(up: Boolean) {
            val from = if (up) 0.54f else 0.18f
            val to = if (up) 0.18f else 0.54f
            line(0.5f, from, 0.5f, to)
            if (up) {
                line(0.5f, to, 0.36f, 0.33f); line(0.5f, to, 0.64f, 0.33f)
            } else {
                line(0.5f, to, 0.36f, 0.39f); line(0.5f, to, 0.64f, 0.39f)
            }
        }
        fun magnifier(cx: Float, cy: Float) {
            drawCircle(color, s * 0.16f, p(cx, cy), style = lineStroke)
            line(cx + 0.12f, cy + 0.12f, cx + 0.25f, cy + 0.25f)
        }
        fun check(x: Float = 0.34f, y: Float = 0.55f) {
            line(x, y, x + 0.11f, y + 0.11f); line(x + 0.11f, y + 0.11f, x + 0.34f, y - 0.16f)
        }

        when (glyph) {
            WmsGlyph.RECEIVING, WmsGlyph.PUT_AWAY -> {
                drawRoundRect(soft, p(0.16f, 0.48f), Size(s * 0.68f, s * 0.34f), CornerRadius(s * 0.08f))
                val tray = Path().apply {
                    moveTo(p(0.16f, 0.48f).x, p(0.16f, 0.48f).y)
                    lineTo(p(0.27f, 0.78f).x, p(0.27f, 0.78f).y)
                    lineTo(p(0.73f, 0.78f).x, p(0.73f, 0.78f).y)
                    lineTo(p(0.84f, 0.48f).x, p(0.84f, 0.48f).y)
                }
                drawPath(tray, color, style = lineStroke)
                arrowDown(up = glyph == WmsGlyph.PUT_AWAY)
            }
            WmsGlyph.PICKING -> {
                val cart = Path().apply {
                    moveTo(p(0.13f, 0.25f).x, p(0.13f, 0.25f).y)
                    lineTo(p(0.23f, 0.25f).x, p(0.23f, 0.25f).y)
                    lineTo(p(0.32f, 0.64f).x, p(0.32f, 0.64f).y)
                    lineTo(p(0.75f, 0.64f).x, p(0.75f, 0.64f).y)
                    lineTo(p(0.82f, 0.36f).x, p(0.82f, 0.36f).y)
                    lineTo(p(0.27f, 0.36f).x, p(0.27f, 0.36f).y)
                }
                drawPath(cart, color, style = lineStroke)
                drawCircle(color, s * 0.055f, p(0.39f, 0.78f))
                drawCircle(color, s * 0.055f, p(0.70f, 0.78f))
                roundRect(0.43f, 0.17f, 0.22f, 0.18f, fill = true)
            }
            WmsGlyph.PACKING -> {
                val box = Path().apply {
                    moveTo(p(0.18f, 0.34f).x, p(0.18f, 0.34f).y)
                    lineTo(p(0.50f, 0.17f).x, p(0.50f, 0.17f).y)
                    lineTo(p(0.82f, 0.34f).x, p(0.82f, 0.34f).y)
                    lineTo(p(0.82f, 0.70f).x, p(0.82f, 0.70f).y)
                    lineTo(p(0.50f, 0.86f).x, p(0.50f, 0.86f).y)
                    lineTo(p(0.18f, 0.70f).x, p(0.18f, 0.70f).y)
                    close()
                }
                drawPath(box, soft)
                drawPath(box, color, style = lineStroke)
                line(0.18f, 0.34f, 0.50f, 0.51f); line(0.82f, 0.34f, 0.50f, 0.51f); line(0.50f, 0.51f, 0.50f, 0.86f)
                line(0.35f, 0.25f, 0.66f, 0.42f)
            }
            WmsGlyph.SHIPPING -> {
                roundRect(0.10f, 0.30f, 0.45f, 0.35f, fill = true)
                roundRect(0.10f, 0.30f, 0.45f, 0.35f)
                val cab = Path().apply {
                    moveTo(p(0.55f, 0.42f).x, p(0.55f, 0.42f).y)
                    lineTo(p(0.72f, 0.42f).x, p(0.72f, 0.42f).y)
                    lineTo(p(0.87f, 0.56f).x, p(0.87f, 0.56f).y)
                    lineTo(p(0.87f, 0.68f).x, p(0.87f, 0.68f).y)
                    lineTo(p(0.55f, 0.68f).x, p(0.55f, 0.68f).y)
                    close()
                }
                drawPath(cab, color, style = lineStroke)
                line(0.72f, 0.42f, 0.72f, 0.56f); line(0.72f, 0.56f, 0.85f, 0.56f)
                drawCircle(color, s * 0.07f, p(0.30f, 0.73f)); drawCircle(color, s * 0.07f, p(0.72f, 0.73f))
            }
            WmsGlyph.LICENSE_PLATE -> {
                roundRect(0.15f, 0.20f, 0.70f, 0.60f, fill = true)
                roundRect(0.15f, 0.20f, 0.70f, 0.60f)
                drawCircle(color, s * 0.055f, p(0.28f, 0.36f))
                listOf(0.42f, 0.49f, 0.58f, 0.66f, 0.73f).forEachIndexed { i, x ->
                    drawLine(color, p(x, 0.32f), p(x, if (i % 2 == 0) 0.68f else 0.62f), strokeWidth * 0.55f, StrokeCap.Round)
                }
            }
            WmsGlyph.HIERARCHY -> {
                // Ürün → kutu → palet: üç seviye tek çizim dilinde görünür.
                roundRect(0.38f, 0.10f, 0.24f, 0.18f, fill = true)
                roundRect(0.38f, 0.10f, 0.24f, 0.18f)
                line(0.50f, 0.28f, 0.50f, 0.39f)
                roundRect(0.25f, 0.39f, 0.50f, 0.27f, fill = true)
                roundRect(0.25f, 0.39f, 0.50f, 0.27f)
                line(0.25f, 0.48f, 0.50f, 0.57f)
                line(0.75f, 0.48f, 0.50f, 0.57f)
                line(0.50f, 0.66f, 0.50f, 0.75f)
                line(0.16f, 0.76f, 0.84f, 0.76f)
                line(0.22f, 0.84f, 0.78f, 0.84f)
                thinLine(0.30f, 0.76f, 0.30f, 0.84f)
                thinLine(0.70f, 0.76f, 0.70f, 0.84f)
            }
            WmsGlyph.AD_HOC -> {
                roundRect(0.11f, 0.19f, 0.26f, 0.25f, fill = true); roundRect(0.63f, 0.56f, 0.26f, 0.25f, fill = true)
                roundRect(0.11f, 0.19f, 0.26f, 0.25f); roundRect(0.63f, 0.56f, 0.26f, 0.25f)
                line(0.39f, 0.34f, 0.79f, 0.34f); line(0.79f, 0.34f, 0.69f, 0.25f); line(0.79f, 0.34f, 0.69f, 0.43f)
                line(0.61f, 0.67f, 0.21f, 0.67f); line(0.21f, 0.67f, 0.31f, 0.58f); line(0.21f, 0.67f, 0.31f, 0.76f)
            }
            WmsGlyph.DIRECTED_MOVE -> {
                drawCircle(soft, s * 0.34f, p(0.50f, 0.50f))
                drawCircle(color, s * 0.34f, p(0.50f, 0.50f), style = lineStroke)
                val needle = Path().apply {
                    moveTo(p(0.64f, 0.25f).x, p(0.64f, 0.25f).y)
                    lineTo(p(0.55f, 0.56f).x, p(0.55f, 0.56f).y)
                    lineTo(p(0.35f, 0.74f).x, p(0.35f, 0.74f).y)
                    lineTo(p(0.44f, 0.43f).x, p(0.44f, 0.43f).y)
                    close()
                }
                drawPath(needle, color, style = lineStroke)
            }
            WmsGlyph.COUNT -> {
                roundRect(0.20f, 0.13f, 0.62f, 0.74f, fill = true); roundRect(0.20f, 0.13f, 0.62f, 0.74f)
                listOf(0.34f, 0.51f, 0.68f).forEach { y ->
                    drawCircle(color, s * 0.025f, p(0.34f, y)); thinLine(0.45f, y, 0.70f, y)
                }
                roundRect(0.38f, 0.08f, 0.26f, 0.14f)
            }
            WmsGlyph.COUNT_V2 -> {
                line(0.17f, 0.34f, 0.17f, 0.18f); line(0.17f, 0.18f, 0.33f, 0.18f)
                line(0.83f, 0.34f, 0.83f, 0.18f); line(0.83f, 0.18f, 0.67f, 0.18f)
                line(0.17f, 0.66f, 0.17f, 0.82f); line(0.17f, 0.82f, 0.33f, 0.82f)
                line(0.83f, 0.66f, 0.83f, 0.82f); line(0.83f, 0.82f, 0.67f, 0.82f)
                check(0.32f, 0.52f)
            }
            WmsGlyph.PRODUCTION -> {
                val factory = Path().apply {
                    moveTo(p(0.12f, 0.80f).x, p(0.12f, 0.80f).y)
                    lineTo(p(0.12f, 0.43f).x, p(0.12f, 0.43f).y)
                    lineTo(p(0.37f, 0.57f).x, p(0.37f, 0.57f).y)
                    lineTo(p(0.37f, 0.42f).x, p(0.37f, 0.42f).y)
                    lineTo(p(0.62f, 0.56f).x, p(0.62f, 0.56f).y)
                    lineTo(p(0.62f, 0.28f).x, p(0.62f, 0.28f).y)
                    lineTo(p(0.78f, 0.28f).x, p(0.78f, 0.28f).y)
                    lineTo(p(0.84f, 0.80f).x, p(0.84f, 0.80f).y)
                    close()
                }
                drawPath(factory, soft); drawPath(factory, color, style = lineStroke)
                thinLine(0.27f, 0.68f, 0.27f, 0.78f); thinLine(0.49f, 0.68f, 0.49f, 0.78f); thinLine(0.69f, 0.65f, 0.69f, 0.78f)
            }
            WmsGlyph.ASSEMBLY -> {
                drawCircle(soft, s * 0.19f, p(0.31f, 0.31f))
                drawCircle(color, s * 0.19f, p(0.31f, 0.31f), style = lineStroke)
                drawCircle(color, s * 0.055f, p(0.31f, 0.31f), style = lineStroke)
                line(0.44f, 0.44f, 0.79f, 0.79f)
                drawCircle(color, s * 0.09f, p(0.79f, 0.79f), style = lineStroke)
                line(0.58f, 0.44f, 0.72f, 0.30f); line(0.72f, 0.30f, 0.83f, 0.34f); line(0.58f, 0.44f, 0.54f, 0.55f)
            }
            WmsGlyph.QUALITY -> {
                val shield = Path().apply {
                    moveTo(p(0.50f, 0.12f).x, p(0.50f, 0.12f).y)
                    lineTo(p(0.81f, 0.25f).x, p(0.81f, 0.25f).y)
                    lineTo(p(0.76f, 0.60f).x, p(0.76f, 0.60f).y)
                    quadraticTo(p(0.68f, 0.78f).x, p(0.68f, 0.78f).y, p(0.50f, 0.88f).x, p(0.50f, 0.88f).y)
                    quadraticTo(p(0.32f, 0.78f).x, p(0.32f, 0.78f).y, p(0.24f, 0.60f).x, p(0.24f, 0.60f).y)
                    lineTo(p(0.19f, 0.25f).x, p(0.19f, 0.25f).y)
                    close()
                }
                drawPath(shield, soft); drawPath(shield, color, style = lineStroke); check(0.32f, 0.51f)
            }
            WmsGlyph.QUALITY_MANAGEMENT -> {
                roundRect(0.19f, 0.16f, 0.62f, 0.70f, fill = true); roundRect(0.19f, 0.16f, 0.62f, 0.70f)
                roundRect(0.37f, 0.10f, 0.26f, 0.13f)
                check(0.30f, 0.55f); thinLine(0.32f, 0.36f, 0.68f, 0.36f)
            }
            WmsGlyph.ITEM_SEARCH -> {
                roundRect(0.11f, 0.19f, 0.45f, 0.45f, fill = true); roundRect(0.11f, 0.19f, 0.45f, 0.45f)
                line(0.11f, 0.34f, 0.335f, 0.47f); line(0.56f, 0.34f, 0.335f, 0.47f)
                magnifier(0.65f, 0.65f)
            }
            WmsGlyph.BIN_SEARCH -> {
                roundRect(0.10f, 0.47f, 0.48f, 0.32f, fill = true); roundRect(0.10f, 0.47f, 0.48f, 0.32f)
                thinLine(0.10f, 0.63f, 0.58f, 0.63f); thinLine(0.34f, 0.47f, 0.34f, 0.79f)
                magnifier(0.66f, 0.37f)
            }
            WmsGlyph.ENTRIES -> {
                // Hareket günlüğü: solda okunaklı liste, sağda giriş/çıkış
                // okları. Eski saat yayı belge çizgileriyle çakışıyordu.
                roundRect(0.10f, 0.12f, 0.56f, 0.76f, fill = true)
                roundRect(0.10f, 0.12f, 0.56f, 0.76f)
                listOf(0.32f, 0.50f, 0.68f).forEach { y ->
                    drawCircle(color, s * 0.027f, p(0.23f, y))
                    thinLine(0.32f, y, 0.54f, y)
                }
                line(0.68f, 0.34f, 0.89f, 0.34f)
                line(0.89f, 0.34f, 0.80f, 0.25f)
                line(0.89f, 0.34f, 0.80f, 0.43f)
                line(0.89f, 0.67f, 0.68f, 0.67f)
                line(0.68f, 0.67f, 0.77f, 0.58f)
                line(0.68f, 0.67f, 0.77f, 0.76f)
            }
            WmsGlyph.FIELD_SETTINGS -> {
                listOf(0.28f, 0.50f, 0.72f).forEach { y -> thinLine(0.15f, y, 0.85f, y) }
                drawCircle(soft, s * 0.085f, p(0.36f, 0.28f)); drawCircle(color, s * 0.085f, p(0.36f, 0.28f), style = lineStroke)
                drawCircle(soft, s * 0.085f, p(0.66f, 0.50f)); drawCircle(color, s * 0.085f, p(0.66f, 0.50f), style = lineStroke)
                drawCircle(soft, s * 0.085f, p(0.43f, 0.72f)); drawCircle(color, s * 0.085f, p(0.43f, 0.72f), style = lineStroke)
            }
            WmsGlyph.HEALTH -> {
                val heart = Path().apply {
                    moveTo(p(0.50f, 0.82f).x, p(0.50f, 0.82f).y)
                    cubicTo(p(0.14f, 0.61f).x, p(0.14f, 0.61f).y, p(0.15f, 0.25f).x, p(0.15f, 0.25f).y, p(0.38f, 0.22f).x, p(0.38f, 0.22f).y)
                    cubicTo(p(0.47f, 0.21f).x, p(0.47f, 0.21f).y, p(0.50f, 0.30f).x, p(0.50f, 0.30f).y, p(0.50f, 0.30f).x, p(0.50f, 0.30f).y)
                    cubicTo(p(0.50f, 0.30f).x, p(0.50f, 0.30f).y, p(0.55f, 0.21f).x, p(0.55f, 0.21f).y, p(0.64f, 0.22f).x, p(0.64f, 0.22f).y)
                    cubicTo(p(0.88f, 0.25f).x, p(0.88f, 0.25f).y, p(0.87f, 0.61f).x, p(0.87f, 0.61f).y, p(0.50f, 0.82f).x, p(0.50f, 0.82f).y)
                }
                drawPath(heart, soft); drawPath(heart, color, style = lineStroke)
                val pulse = Path().apply { moveTo(p(0.23f, 0.52f).x, p(0.23f, 0.52f).y); lineTo(p(0.39f, 0.52f).x, p(0.39f, 0.52f).y); lineTo(p(0.46f, 0.39f).x, p(0.46f, 0.39f).y); lineTo(p(0.56f, 0.64f).x, p(0.56f, 0.64f).y); lineTo(p(0.64f, 0.52f).x, p(0.64f, 0.52f).y); lineTo(p(0.77f, 0.52f).x, p(0.77f, 0.52f).y) }
                drawPath(pulse, color, style = thin)
            }
            WmsGlyph.PRINTER -> {
                roundRect(0.24f, 0.12f, 0.52f, 0.28f, fill = true); roundRect(0.24f, 0.12f, 0.52f, 0.28f)
                roundRect(0.12f, 0.35f, 0.76f, 0.35f); roundRect(0.25f, 0.58f, 0.50f, 0.28f, fill = true); roundRect(0.25f, 0.58f, 0.50f, 0.28f)
                drawCircle(color, s * 0.025f, p(0.74f, 0.48f))
            }
            WmsGlyph.TEST -> {
                line(0.38f, 0.14f, 0.62f, 0.14f); line(0.44f, 0.14f, 0.44f, 0.42f); line(0.56f, 0.14f, 0.56f, 0.42f)
                val flask = Path().apply { moveTo(p(0.44f, 0.42f).x, p(0.44f, 0.42f).y); lineTo(p(0.20f, 0.78f).x, p(0.20f, 0.78f).y); quadraticTo(p(0.18f, 0.86f).x, p(0.18f, 0.86f).y, p(0.30f, 0.86f).x, p(0.30f, 0.86f).y); lineTo(p(0.70f, 0.86f).x, p(0.70f, 0.86f).y); quadraticTo(p(0.82f, 0.86f).x, p(0.82f, 0.86f).y, p(0.80f, 0.78f).x, p(0.80f, 0.78f).y); lineTo(p(0.56f, 0.42f).x, p(0.56f, 0.42f).y) }
                drawPath(flask, color, style = lineStroke)
                val liquid = Path().apply { moveTo(p(0.29f, 0.67f).x, p(0.29f, 0.67f).y); quadraticTo(p(0.48f, 0.59f).x, p(0.48f, 0.59f).y, p(0.70f, 0.67f).x, p(0.70f, 0.67f).y); lineTo(p(0.78f, 0.80f).x, p(0.78f, 0.80f).y); lineTo(p(0.22f, 0.80f).x, p(0.22f, 0.80f).y); close() }
                drawPath(liquid, soft)
            }
            WmsGlyph.POSTING -> {
                roundRect(0.20f, 0.14f, 0.60f, 0.72f, fill = true); roundRect(0.20f, 0.14f, 0.60f, 0.72f)
                line(0.50f, 0.70f, 0.50f, 0.36f); line(0.50f, 0.36f, 0.37f, 0.49f); line(0.50f, 0.36f, 0.63f, 0.49f)
                thinLine(0.35f, 0.76f, 0.65f, 0.76f)
            }
            WmsGlyph.CONNECTION -> {
                // İnternet bağlantısını anlatan sade dünya simgesi.
                drawCircle(soft, s * 0.35f, p(0.50f, 0.50f))
                drawCircle(color, s * 0.35f, p(0.50f, 0.50f), style = lineStroke)
                drawOval(
                    color = color,
                    topLeft = p(0.36f, 0.15f),
                    size = Size(s * 0.28f, s * 0.70f),
                    style = thin,
                )
                thinLine(0.18f, 0.50f, 0.82f, 0.50f)
                thinLine(0.23f, 0.33f, 0.77f, 0.33f)
                thinLine(0.23f, 0.67f, 0.77f, 0.67f)
            }
            WmsGlyph.HELP -> {
                drawCircle(soft, s * 0.36f, p(0.50f, 0.50f)); drawCircle(color, s * 0.36f, p(0.50f, 0.50f), style = lineStroke)
                drawArc(color, 190f, 235f, false, p(0.36f, 0.25f), Size(s * 0.30f, s * 0.31f), style = lineStroke)
                line(0.50f, 0.53f, 0.50f, 0.62f); drawCircle(color, s * 0.035f, p(0.50f, 0.73f))
            }
            WmsGlyph.WARNING -> {
                val triangle = Path().apply { moveTo(p(0.50f, 0.12f).x, p(0.50f, 0.12f).y); lineTo(p(0.88f, 0.82f).x, p(0.88f, 0.82f).y); lineTo(p(0.12f, 0.82f).x, p(0.12f, 0.82f).y); close() }
                drawPath(triangle, soft); drawPath(triangle, color, style = lineStroke)
                line(0.50f, 0.36f, 0.50f, 0.58f); drawCircle(color, s * 0.035f, p(0.50f, 0.70f))
            }
            WmsGlyph.SCAN -> {
                line(0.14f, 0.34f, 0.14f, 0.16f); line(0.14f, 0.16f, 0.32f, 0.16f)
                line(0.86f, 0.34f, 0.86f, 0.16f); line(0.86f, 0.16f, 0.68f, 0.16f)
                line(0.14f, 0.66f, 0.14f, 0.84f); line(0.14f, 0.84f, 0.32f, 0.84f)
                line(0.86f, 0.66f, 0.86f, 0.84f); line(0.86f, 0.84f, 0.68f, 0.84f)
                listOf(0.34f, 0.43f, 0.53f, 0.62f, 0.70f).forEachIndexed { i, x -> thinLine(x, 0.31f, x, if (i % 2 == 0) 0.70f else 0.64f) }
            }
            WmsGlyph.REFRESH -> {
                // İki dengeli ok: küçük terminal ekranında da yönü ve yenileme
                // anlamı net kalır; ok uçları yayın gerçek uçlarına bağlıdır.
                drawArc(color, 205f, 205f, false, p(0.17f, 0.17f), Size(s * 0.66f, s * 0.66f), style = lineStroke)
                line(0.77f, 0.25f, 0.78f, 0.45f)
                line(0.77f, 0.25f, 0.57f, 0.28f)
                drawArc(color, 25f, 145f, false, p(0.17f, 0.17f), Size(s * 0.66f, s * 0.66f), style = lineStroke)
                line(0.23f, 0.75f, 0.22f, 0.55f)
                line(0.23f, 0.75f, 0.43f, 0.72f)
            }
            WmsGlyph.CLOSE -> { line(0.24f, 0.24f, 0.76f, 0.76f); line(0.76f, 0.24f, 0.24f, 0.76f) }
            WmsGlyph.CHEVRON -> { line(0.38f, 0.23f, 0.64f, 0.50f); line(0.64f, 0.50f, 0.38f, 0.77f) }
            WmsGlyph.LAYOUT -> {
                roundRect(0.12f, 0.14f, 0.30f, 0.30f, fill = true); roundRect(0.12f, 0.14f, 0.30f, 0.30f)
                roundRect(0.58f, 0.14f, 0.30f, 0.30f); roundRect(0.12f, 0.60f, 0.30f, 0.26f)
                roundRect(0.58f, 0.60f, 0.30f, 0.26f, fill = true); roundRect(0.58f, 0.60f, 0.30f, 0.26f)
            }
        }
    }
}
