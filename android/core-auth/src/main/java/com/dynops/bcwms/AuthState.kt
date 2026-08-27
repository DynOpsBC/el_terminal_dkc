package com.dynops.bcwms.core.auth

sealed interface AuthState {
  data object SignedOut : AuthState
  data class SignedIn(val accountId: String) : AuthState
  data class Error(val message: String) : AuthState
}

interface MsalAuthClient {
  suspend fun signIn(): AuthState
  suspend fun acquireToken(scopes: List<String>): String
}

interface TokenStore {
  suspend fun saveAccessToken(accessToken: String)
  suspend fun getAccessToken(): String?
}

data class ProfileStore(
  val tenantId: String = "7fa2357e-26f2-4174-8e16-a713981356b8",
  val environmentName: String = "CustomerSandbox",
  val companyName: String = "Demo Business Central",
)

