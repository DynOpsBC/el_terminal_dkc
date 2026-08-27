package com.dynops.bcwms.push

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

data class PickReassignedMessage(val pickNo: String, val assignedUserId: String)

object PickReassignedNotification {
  private val mutableEvents = MutableSharedFlow<PickReassignedMessage>(extraBufferCapacity = 8)
  val events: SharedFlow<PickReassignedMessage> = mutableEvents.asSharedFlow()

  fun handle(data: Map<String, String>): Boolean {
    if (data["type"] != "pick.reassigned") return false
    val pickNo = data["pickNo"].orEmpty()
    val userId = data["userId"].orEmpty()
    if (pickNo.isBlank()) return false
    mutableEvents.tryEmit(PickReassignedMessage(pickNo, userId))
    return true
  }

  fun snackbarText(message: PickReassignedMessage): String =
    "Toplama ${message.pickNo}${message.assignedUserId.takeIf { it.isNotBlank() }?.let { " → $it kullanıcısına atandı" } ?: " yeniden atandı"}"
}
