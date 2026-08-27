package com.dynops.bcwms.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * BCWMS Material3 theme — design tokens ported from the DynOps Precious Metal
 * App. Brand accent is iris violet (#6c5ce7); light mode runs on a warm cream
 * surface, dark mode on deep charcoal blue. Status, warning and danger colors
 * mirror the web token set in `web/src/styles.css`.
 */

// Iris brand
private val IrisLight = Color(0xFF4F46E5)
private val IrisDark = Color(0xFF8B7DD8)

// Light tokens
private val BackgroundLight = Color(0xFFF6F7F9)
private val SurfaceLight = Color(0xFFFFFFFF)
private val SurfaceVariantLight = Color(0xFFEEF1F5)
private val OnSurfaceLight = Color(0xFF18212F)
private val OnSurfaceVariantLight = Color(0xFF667085)
private val AccentBgLight = Color(0xFFEEF2FF)
private val AccentFgLight = Color(0xFF4338CA)
private val OutlineLight = Color(0xFFD8DEE8)
private val ErrorLight = Color(0xFFE74C3C)
private val OnErrorLight = Color(0xFFFFFFFF)

// Dark tokens
private val BackgroundDark = Color(0xFF0F1419)
private val SurfaceDark = Color(0xFF141B28)
private val SurfaceVariantDark = Color(0xFF242D3D)
private val OnSurfaceDark = Color(0xFFE8EAED)
private val OnSurfaceVariantDark = Color(0xFF9CA3AF)
private val AccentBgDark = Color(0xFF3A2F5F)
private val AccentFgDark = Color(0xFFDBD5FF)
private val OutlineDark = Color(0xFF2D3748)
private val ErrorDark = Color(0xFFF87171)
private val OnErrorDark = Color(0xFF1A0E0E)

private val LightColors = lightColorScheme(
    primary = IrisLight,
    onPrimary = Color.White,
    primaryContainer = AccentBgLight,
    onPrimaryContainer = AccentFgLight,
    secondary = SurfaceVariantLight,
    onSecondary = OnSurfaceLight,
    tertiary = Color(0xFF26A65B),
    background = BackgroundLight,
    onBackground = OnSurfaceLight,
    surface = SurfaceLight,
    onSurface = OnSurfaceLight,
    surfaceVariant = SurfaceVariantLight,
    onSurfaceVariant = OnSurfaceVariantLight,
    outline = OutlineLight,
    outlineVariant = OutlineLight,
    error = ErrorLight,
    onError = OnErrorLight,
)

private val DarkColors = darkColorScheme(
    primary = IrisDark,
    onPrimary = Color(0xFF0A0E18),
    primaryContainer = AccentBgDark,
    onPrimaryContainer = AccentFgDark,
    secondary = SurfaceVariantDark,
    onSecondary = OnSurfaceDark,
    tertiary = Color(0xFF34D399),
    background = BackgroundDark,
    onBackground = OnSurfaceDark,
    surface = SurfaceDark,
    onSurface = OnSurfaceDark,
    surfaceVariant = SurfaceVariantDark,
    onSurfaceVariant = OnSurfaceVariantDark,
    outline = OutlineDark,
    outlineVariant = OutlineDark,
    error = ErrorDark,
    onError = OnErrorDark,
)

// Status palette exposed for badges/pills that don't fit Material3 ColorScheme.
data class BcwmsStatus(
    val success: Color,
    val warning: Color,
    val danger: Color,
    val accent: Color,
)

val BcwmsStatusLight = BcwmsStatus(
    success = Color(0xFF26A65B),
    warning = Color(0xFFFFA500),
    danger = ErrorLight,
    accent = IrisLight,
)
val BcwmsStatusDark = BcwmsStatus(
    success = Color(0xFF34D399),
    warning = Color(0xFFFBBF24),
    danger = ErrorDark,
    accent = IrisDark,
)

private val DisplayFamily = FontFamily.Serif
private val BodyFamily = FontFamily.Default

// El terminali (handheld) için okunabilirlik: temel gövde/başlık boyutları ve
// buton etiketleri (labelLarge) bir tık büyütüldü — eldivenle/tek elle kullanım
// ve tarayıcı-öncelikli akış için daha büyük dokunma hedefleri.
private val BcwmsTypography = Typography(
    displayLarge = TextStyle(fontFamily = DisplayFamily, fontWeight = FontWeight.SemiBold, fontSize = 32.sp, letterSpacing = (-0.02).sp),
    displayMedium = TextStyle(fontFamily = DisplayFamily, fontWeight = FontWeight.SemiBold, fontSize = 26.sp, letterSpacing = (-0.02).sp),
    displaySmall = TextStyle(fontFamily = DisplayFamily, fontWeight = FontWeight.SemiBold, fontSize = 22.sp, letterSpacing = (-0.01).sp),
    headlineLarge = TextStyle(fontFamily = DisplayFamily, fontWeight = FontWeight.SemiBold, fontSize = 22.sp),
    headlineMedium = TextStyle(fontFamily = DisplayFamily, fontWeight = FontWeight.SemiBold, fontSize = 19.sp),
    headlineSmall = TextStyle(fontFamily = DisplayFamily, fontWeight = FontWeight.SemiBold, fontSize = 17.sp),
    titleLarge = TextStyle(fontFamily = BodyFamily, fontWeight = FontWeight.SemiBold, fontSize = 18.sp),
    titleMedium = TextStyle(fontFamily = BodyFamily, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, letterSpacing = (-0.01).sp),
    titleSmall = TextStyle(fontFamily = BodyFamily, fontWeight = FontWeight.Medium, fontSize = 14.sp),
    bodyLarge = TextStyle(fontFamily = BodyFamily, fontWeight = FontWeight.Normal, fontSize = 16.sp),
    bodyMedium = TextStyle(fontFamily = BodyFamily, fontWeight = FontWeight.Normal, fontSize = 15.sp),
    bodySmall = TextStyle(fontFamily = BodyFamily, fontWeight = FontWeight.Normal, fontSize = 13.sp),
    labelLarge = TextStyle(fontFamily = BodyFamily, fontWeight = FontWeight.SemiBold, fontSize = 15.sp),
    labelMedium = TextStyle(fontFamily = BodyFamily, fontWeight = FontWeight.Medium, fontSize = 13.sp, letterSpacing = 0.4.sp),
    labelSmall = TextStyle(fontFamily = BodyFamily, fontWeight = FontWeight.Medium, fontSize = 12.sp, letterSpacing = 0.6.sp),
)

@Composable
fun BcwmsTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colors = if (darkTheme) DarkColors else LightColors
    MaterialTheme(
        colorScheme = colors,
        typography = BcwmsTypography,
        content = content,
    )
}

@Composable
fun bcwmsStatus(): BcwmsStatus =
    if (isSystemInDarkTheme()) BcwmsStatusDark else BcwmsStatusLight
