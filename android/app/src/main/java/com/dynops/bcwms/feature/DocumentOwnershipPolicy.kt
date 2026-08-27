package com.dynops.bcwms.feature

/**
 * Warehouse documents are mutable only by their explicitly assigned WMS user.
 * A missing assignment or unresolved local identity is deliberately read-only;
 * callers may expose an atomic server-side claim action separately.
 */
internal fun canMutateAssignedDocument(assignedUserId: String, localUserId: String): Boolean =
    assignedUserId.isNotBlank() && localUserId.isNotBlank() &&
        assignedUserId.trim().equals(localUserId.trim(), ignoreCase = true)

internal fun documentOwnershipMessage(assignedUserId: String, localUserId: String): String = when {
    localUserId.isBlank() -> "Depo kullanıcısı doğrulanamadı. Yeniden giriş yapın."
    assignedUserId.isBlank() -> "Belge henüz bir kullanıcıya atanmadı. Önce belgeyi üzerinize alın."
    canMutateAssignedDocument(assignedUserId, localUserId) -> ""
    else -> "Bu belge $assignedUserId kullanıcısına atanmış. İşlem yapılamaz."
}
