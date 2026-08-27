package com.dynops.bcwms.network

class PushTokenRegistrar(
  private val registerToken: suspend (deviceId: String, fcmToken: String) -> Result<Unit>,
) {
  suspend fun registerOnAuth(deviceId: String, fcmToken: String?): Result<Unit> {
    if (deviceId.isBlank() || fcmToken.isNullOrBlank()) return Result.success(Unit)
    return registerToken(deviceId, fcmToken)
  }
}
