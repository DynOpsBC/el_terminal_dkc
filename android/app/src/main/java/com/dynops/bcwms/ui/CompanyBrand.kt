package com.dynops.bcwms.ui

import androidx.annotation.DrawableRes
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dynops.bcwms.R
import java.util.Locale

/**
 * Aynı APK içindeki şirketlerin görsel kimliği. Eşleme şirketin görünen adına
 * göre yapılır; Business Central şirket kimliği değişse bile marka doğru kalır.
 */
enum class CompanyBrand(
    val shortName: String,
    val primary: Color,
    val secondary: Color,
    @DrawableRes val logoRes: Int?,
) {
    BADE(
        shortName = "Bade Natural",
        primary = Color(0xFF137A4B),
        secondary = Color(0xFF24A269),
        logoRes = R.drawable.logo_bade_natural,
    ),
    BS(
        shortName = "BS Group",
        primary = Color(0xFF2B3077),
        secondary = Color(0xFF4D57B7),
        logoRes = R.drawable.logo_bs_group,
    ),
    PIM(
        shortName = "PİM Grup",
        primary = Color(0xFFD91F2B),
        secondary = Color(0xFFA4203B),
        logoRes = R.drawable.logo_pim_grup,
    ),
    DEFAULT(
        shortName = "WMS",
        primary = Color(0xFF6C5CE7),
        secondary = Color(0xFF4A3DB8),
        logoRes = null,
    ),
}

internal fun normalizedCompanyName(value: String): String =
    value.trim().uppercase(Locale.ROOT).replace('İ', 'I')

/** Saf fonksiyon olması, yanlış şirkette yanlış rengin görünmesini test edilebilir kılar. */
fun resolveCompanyBrand(companyName: String, flavor: String = ""): CompanyBrand {
    val normalized = normalizedCompanyName(companyName)
    return when {
        // EMU/DKÇ ayrı müşteri paketidir; önceki kurulumdan taşınmış bir şirket
        // adı olsa dahi BADE/BS/PİM görseli göstermez, genel WMS kimliğini kullanır.
        flavor.equals("emu", ignoreCase = true) -> CompanyBrand.DEFAULT
        "BADE" in normalized -> CompanyBrand.BADE
        "PIM" in normalized -> CompanyBrand.PIM
        "BS GROUP" in normalized || "BSGROUP" in normalized || "BS GRUP" in normalized -> CompanyBrand.BS
        companyName.isBlank() && flavor.equals("bade", ignoreCase = true) -> CompanyBrand.BADE
        else -> CompanyBrand.DEFAULT
    }
}

/**
 * Logolar yalnız beyaz bir marka zemini üzerinde gösterilir. Bu sayede siyah
 * Bade wordmark'ı ve şeffaf BS/PİM logoları her şirket banner'ında okunur.
 */
@Composable
fun CompanyLogo(
    brand: CompanyBrand,
    modifier: Modifier = Modifier,
    height: Dp = 48.dp,
) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(12.dp),
        color = Color.White,
        tonalElevation = 0.dp,
    ) {
        Box(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 7.dp),
            contentAlignment = Alignment.Center,
        ) {
            val logo = brand.logoRes
            if (logo != null) {
                androidx.compose.foundation.Image(
                    painter = painterResource(logo),
                    contentDescription = "${brand.shortName} logosu",
                    modifier = Modifier.size(width = height * 2.55f, height = height),
                    contentScale = ContentScale.Fit,
                )
            } else {
                Box(
                    Modifier.size(width = height * 1.9f, height = height)
                        .background(brand.primary.copy(alpha = 0.10f), RoundedCornerShape(9.dp)),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        "WMS",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Black,
                        fontSize = 18.sp,
                        color = brand.primary,
                    )
                }
            }
        }
    }
}
