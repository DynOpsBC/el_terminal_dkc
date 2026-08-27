package com.dynops.bcwms.feature.auth

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL

@Composable
fun LoginScreen(
  state: AuthUiState = AuthUiState(),
  onSignIn: () -> Unit = {},
) {
  var token by remember { mutableStateOf("") }
  var status by remember { mutableStateOf("BCWMSApp Mobile v1.0.0 — BC Sandbox: CustomerSandbox / Demo Business Central") }
  var result by remember { mutableStateOf("") }
  var loading by remember { mutableStateOf(false) }
  val scope = rememberCoroutineScope()

  Column(
    modifier = Modifier
      .fillMaxSize()
      .padding(16.dp)
      .verticalScroll(rememberScrollState())
  ) {
    Text("📱 BCWMS Mobile App", style = MaterialTheme.typography.headlineSmall)
    Spacer(Modifier.height(8.dp))
    Text(status, style = MaterialTheme.typography.bodySmall)
    Spacer(Modifier.height(16.dp))

    OutlinedTextField(
      value = token,
      onValueChange = { token = it },
      label = { Text("Azure AD Access Token") },
      modifier = Modifier.fillMaxWidth(),
      visualTransformation = PasswordVisualTransformation(),
      singleLine = false,
      maxLines = 3,
    )
    Spacer(Modifier.height(8.dp))
    Text(
      "Token alma: az account get-access-token --resource https://api.businesscentral.dynamics.com --query accessToken -o tsv",
      style = MaterialTheme.typography.labelSmall,
    )
    Spacer(Modifier.height(16.dp))

    Row {
      Button(
        enabled = token.isNotBlank() && !loading,
        onClick = {
          scope.launch {
            loading = true
            result = fetchLicensePlates(token)
            loading = false
          }
        }
      ) { Text(if (loading) "Loading..." else "📦 Fetch License Plates (LP API)") }
      Spacer(Modifier.width(8.dp))
      Button(
        enabled = token.isNotBlank() && !loading,
        onClick = {
          scope.launch {
            loading = true
            result = fetchTestRuns(token)
            loading = false
          }
        }
      ) { Text("🧪 Test Runs") }
    }
    Spacer(Modifier.height(16.dp))

    if (result.isNotBlank()) {
      Card(modifier = Modifier.fillMaxWidth()) {
        Text(
          result,
          modifier = Modifier.padding(12.dp),
          style = MaterialTheme.typography.bodySmall,
        )
      }
    }
  }
}

private suspend fun fetchLicensePlates(token: String): String = withContext(Dispatchers.IO) {
  try {
    val url = URL("https://api.businesscentral.dynamics.com/v2.0/7fa2357e-26f2-4174-8e16-a713981356b8/CustomerSandbox/api/dynops/warehouse/v2.0/companies(e83a57e9-38c9-f011-8542-6045bd6aeb9e)/licensePlates?\$top=5&\$select=no,status,locationCode,binCode,templateCode")
    val conn = url.openConnection() as HttpURLConnection
    conn.setRequestProperty("Authorization", "Bearer $token")
    conn.setRequestProperty("Accept", "application/json")
    val code = conn.responseCode
    val body = if (code in 200..299) {
      conn.inputStream.bufferedReader().readText()
    } else {
      conn.errorStream?.bufferedReader()?.readText() ?: "no body"
    }
    "HTTP $code\n\n${body.take(1500)}"
  } catch (e: Exception) {
    "Hata: ${e.message}"
  }
}

private suspend fun fetchTestRuns(token: String): String = withContext(Dispatchers.IO) {
  try {
    val url = URL("https://api.businesscentral.dynamics.com/v2.0/7fa2357e-26f2-4174-8e16-a713981356b8/CustomerSandbox/api/dynops/warehouse/v2.0/companies(e83a57e9-38c9-f011-8542-6045bd6aeb9e)/testRuns?\$top=5&\$select=runNo,status,totalCases,passed,failed,passRate,durationSec")
    val conn = url.openConnection() as HttpURLConnection
    conn.setRequestProperty("Authorization", "Bearer $token")
    conn.setRequestProperty("Accept", "application/json")
    val code = conn.responseCode
    val body = if (code in 200..299) {
      conn.inputStream.bufferedReader().readText()
    } else {
      conn.errorStream?.bufferedReader()?.readText() ?: "no body"
    }
    "HTTP $code\n\n${body.take(1500)}"
  } catch (e: Exception) {
    "Hata: ${e.message}"
  }
}
