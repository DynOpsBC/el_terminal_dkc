package com.dynops.bcwms.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp

/**
 * Standart belge no arama kutusu. Tüm list ekranları (Picking, Receiving,
 * PutAway, Shipping, Movement, Count, LP, Production, Assembly, Quality)
 * burayı kullanır — PDF QA review M1.2 kapsamı.
 *
 * `onSearch` enter'a basıldığında veya arama ikonuna tıklandığında çağrılır.
 * Boş içerikle çağrı da geçerli (kullanıcı sıfırlamak istiyor).
 */
@Composable
fun DocSearchBar(
    value: String,
    onValueChange: (String) -> Unit,
    onSearch: () -> Unit,
    label: String = "Belge no ile ara",
    modifier: Modifier = Modifier,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        singleLine = true,
        label = { Text(label) },
        trailingIcon = {
            TextButton(onClick = onSearch) {
                WmsIcon(WmsGlyph.ITEM_SEARCH, MaterialTheme.colorScheme.primary, Modifier.size(21.dp))
            }
        },
        keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(imeAction = ImeAction.Search),
        keyboardActions = androidx.compose.foundation.text.KeyboardActions(onSearch = { onSearch() }),
        modifier = modifier.fillMaxWidth(),
    )
}

/**
 * OData $filter clause'larını güvenli birleştirir. Boş clause'ları atar,
 * tek-tırnak escape eder, hiç clause yoksa boş string döndürür.
 *
 * Kullanım:
 *   val filter = buildODataFilter(
 *     "status eq 'Released'".takeIf { releasedOnly },
 *     searchClause("no", search),
 *   )
 *   val url = "picks?\$top=100$filter"
 */
fun buildODataFilter(vararg clauses: String?): String {
    val active = clauses.filterNotNull().filter { it.isNotBlank() }
    if (active.isEmpty()) return ""
    return "&\$filter=" + active.joinToString(" and ")
}

/** "startswith(no,'X')" pattern'i için helper. Boş search → null döner. */
fun searchClause(field: String, search: String): String? {
    val q = search.trim()
    if (q.isBlank()) return null
    return "startswith($field,'${q.replace("'", "''")}')"
}

/**
 * "Bana atanan" chip'i için assignedUserId eşitlik clause'u. BC "Assigned User ID"
 * alanları büyük harf Code değerleri tutar; userId BcApi.currentUserId'den gelir.
 * enabled=false ("Tümü" seçili) → null. "Bana atanan" seçiliyken kullanıcı
 * çözülemediyse güvenli tarafta kalır ve sonuç döndürmeyen bir clause üretir;
 * aksi halde tüm belgeleri açmak yetki/iş sahipliği ihlaline yol açabilir.
 */
fun assignedToMeClause(userId: String, enabled: Boolean = true): String? {
    if (!enabled) return null
    if (userId.isBlank()) return "assignedUserId eq '__BCWMS_USER_UNRESOLVED__'"
    return "assignedUserId eq '${userId.trim().uppercase().replace("'", "''")}'"
}

/** Assigned-only queues must not query with a shared/unknown warehouse user. */
fun canLoadAssignedOnlyList(showAll: Boolean, localUserId: String): Boolean =
    showAll || localUserId.isNotBlank()
