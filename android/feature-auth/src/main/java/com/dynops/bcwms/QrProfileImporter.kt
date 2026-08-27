package com.dynops.bcwms.feature.auth

import com.dynops.bcwms.core.domain.ConnectionProfile
import org.json.JSONObject

class QrProfileImporter {
  fun parse(raw: String): Result<ConnectionProfile> = runCatching {
    val json = JSONObject(raw)
    ConnectionProfile(
      tenantId = json.getString("tenant"),
      environmentName = json.getString("env"),
      companyName = json.getString("company"),
      deviceConfigCode = json.optString("deviceConfig", "DEFAULT"),
    )
  }
}
