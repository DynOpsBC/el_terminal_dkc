param location string = resourceGroup().location
@minLength(2)
@maxLength(20)
param appName string

var compactAppName = replace(replace(toLower(appName), '-', ''), '_', '')
var storageName = take('${compactAppName}${uniqueString(resourceGroup().id, appName)}', 24)

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${appName}-appi'
  location: location
  kind: 'web'
  properties: { Application_Type: 'web' }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: '${appName}-kv'
  location: location
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
  }
}

resource signalr 'Microsoft.SignalRService/webPubSub@2023-02-01' = {
  name: '${appName}-wps'
  location: location
  sku: {
    name: 'Standard_S1'
    capacity: 1
  }
  properties: {
    disableAadAuth: false
    disableLocalAuth: false
  }
}

resource plan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: '${appName}-premium-plan'
  location: location
  kind: 'elastic'
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
    family: 'EP'
    capacity: 1
  }
  properties: {
    reserved: true
    maximumElasticWorkerCount: 1
  }
}

resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: appName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    siteConfig: {
      linuxFxVersion: 'Node|20'
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storage.listKeys().keys[0].value}'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'AzureSignalRConnectionString'
          value: signalr.listKeys().primaryConnectionString
        }
        {
          name: 'TENANT_CONFIG_JSON'
          value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/tenant-config/)'
        }
        {
          name: 'PRINT_TENANT_CONFIG_JSON'
          value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/print-tenant-config/)'
        }
      ]
    }
    httpsOnly: true
  }
}

resource functionSecretsReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, functionApp.id, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6'
    )
  }
}

output functionAppName string = functionApp.name
output signalRName string = signalr.name
output keyVaultName string = keyVault.name
