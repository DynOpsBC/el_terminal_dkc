package com.dynops.bcwms.feature.auth

import androidx.lifecycle.ViewModel

data class AuthUiState(
  val loading: Boolean = false,
  val statusText: String = "Signed out",
)

data class ConnectionProfileUiState(
  val tenantId: String = "7fa2357e-26f2-4174-8e16-a713981356b8",
  val environmentName: String = "CustomerSandbox",
  val companyName: String = "Demo Business Central",
  val deviceConfigCode: String = "DEFAULT",
)

sealed interface AuthIntent {
  data object SignIn : AuthIntent
  data class UpdateProfile(val profile: ConnectionProfileUiState) : AuthIntent
}

class AuthViewModel : ViewModel() {
  var state: AuthUiState = AuthUiState()
    private set

  fun handle(intent: AuthIntent) {
    state = when (intent) {
      AuthIntent.SignIn -> state.copy(loading = true, statusText = "Starting sign in")
      is AuthIntent.UpdateProfile -> state
    }
  }
}
