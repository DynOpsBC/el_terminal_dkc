package com.dynops.bcwms.core.domain.usecase

data class DeviceRegistration(
  val deviceId: String,
  val fingerprint: String,
  val appVersion: String,
  val configCode: String,
)

fun interface RegisterDevice {
  suspend operator fun invoke(deviceId: String, fingerprint: String, appVersion: String): Result<DeviceRegistration>
}
