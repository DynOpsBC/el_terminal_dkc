targetScope = 'resourceGroup'

metadata name = 'BC WMS direct Azure print infrastructure'
metadata description = 'Private Blob Storage and least-privilege Service Bus queues for direct Business Central to print-agent delivery.'

@description('Short lowercase prefix. Deploy.ps1 enforces: starts with a letter and contains only lowercase letters, digits, or hyphens.')
@minLength(2)
@maxLength(18)
param namePrefix string

@description('Canonical first StationId segment for this single-company deployment.')
@minLength(1)
@maxLength(32)
param routingTenantId string

@description('Canonical second StationId segment for this single-company deployment.')
@minLength(1)
@maxLength(32)
param routingCompanyId string

@description('Deployment stage. It becomes part of globally unique resource names.')
@allowed([
  'dev'
  'sandbox'
  'test'
  'uat'
  'prod'
])
param environmentName string = 'sandbox'

@description('Azure region. Keep Service Bus, Storage, and diagnostics in the same region.')
param location string = resourceGroup().location

@description('Delete live print payloads this many days after their last modification.')
@minValue(8)
@maxValue(30)
param payloadRetentionDays int = 14

@description('Retain Azure Monitor diagnostic data for this many days.')
@minValue(30)
@maxValue(730)
param diagnosticRetentionDays int = 30

@description('Deploy a Log Analytics workspace and diagnostic settings. Disable only for short-lived cost-constrained sandboxes.')
param enableDiagnostics bool = true

@description('Optional common Azure tags.')
param tags object = {}

var compactPrefix = replace(toLower(namePrefix), '-', '')
var uniqueSuffix = uniqueString(subscription().subscriptionId, resourceGroup().id, namePrefix, environmentName)
// Keep the complete 13-character unique suffix; taking the full concatenation
// could truncate it for long prefixes and cause global-name collisions.
var storageAccountName = 'st${take('${compactPrefix}${environmentName}', 9)}${uniqueSuffix}'
var serviceBusNamespaceName = take('${toLower(namePrefix)}-${environmentName}-${uniqueSuffix}', 50)
var logAnalyticsWorkspaceName = take('log-${toLower(namePrefix)}-${environmentName}-${uniqueSuffix}', 63)
var printJobsContainerName = 'print-jobs'
var printJobsQueueName = 'print-jobs-queue'
var printerStatusQueueName = 'printer-status-queue'
var commonTags = union(tags, {
  application: 'bc-wms-direct-print'
  environment: environmentName
  managedBy: 'bicep'
  dataClassification: 'operational'
  routingScope: '${routingTenantId}.${routingCompanyId}'
})

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: commonTags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowSharedKeyAccess: true
    defaultToOAuthAuthentication: false
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Enabled'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource printJobsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: printJobsContainerName
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: true
    publicAccess: 'None'
  }
}

resource storageLifecycle 'Microsoft.Storage/storageAccounts/managementPolicies@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          name: 'delete-expired-print-payloads'
          enabled: true
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: [
                'blockBlob'
              ]
              prefixMatch: [
                '${printJobsContainerName}/'
              ]
            }
            actions: {
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: payloadRetentionDays
                }
              }
              snapshot: {
                delete: {
                  daysAfterCreationGreaterThan: payloadRetentionDays
                }
              }
              version: {
                delete: {
                  daysAfterCreationGreaterThan: payloadRetentionDays
                }
              }
            }
          }
        }
      ]
    }
  }
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  name: serviceBusNamespaceName
  location: location
  tags: commonTags
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    disableLocalAuth: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    zoneRedundant: false
  }
}

resource printJobsQueue 'Microsoft.ServiceBus/namespaces/queues@2024-01-01' = {
  parent: serviceBusNamespace
  name: printJobsQueueName
  properties: {
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    deadLetteringOnMessageExpiration: true
    // Keep jobs through a full week-long workstation outage. Blob payloads
    // default to 14 days so a live queue message never races lifecycle deletion.
    defaultMessageTimeToLive: 'P7D'
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    enableExpress: false
    enablePartitioning: false
    lockDuration: 'PT5M'
    maxDeliveryCount: 10
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: true
    requiresSession: true
    status: 'Active'
  }
}

resource printerStatusQueue 'Microsoft.ServiceBus/namespaces/queues@2024-01-01' = {
  parent: serviceBusNamespace
  name: printerStatusQueueName
  properties: {
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    deadLetteringOnMessageExpiration: true
    defaultMessageTimeToLive: 'P7D'
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    enableExpress: false
    enablePartitioning: false
    lockDuration: 'PT1M'
    maxDeliveryCount: 10
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: true
    requiresSession: false
    status: 'Active'
  }
}

// Queue-level policies prevent any component from accessing the other queue or
// receiving a permission it does not need. No application uses RootManageSharedAccessKey.
resource bcSendJobsRule 'Microsoft.ServiceBus/namespaces/queues/authorizationRules@2024-01-01' = {
  parent: printJobsQueue
  name: 'bc-send-jobs'
  properties: {
    rights: [
      'Send'
    ]
  }
}

resource agentListenJobsRule 'Microsoft.ServiceBus/namespaces/queues/authorizationRules@2024-01-01' = {
  parent: printJobsQueue
  name: 'agent-listen-jobs'
  properties: {
    rights: [
      'Listen'
    ]
  }
}

resource agentSendStatusRule 'Microsoft.ServiceBus/namespaces/queues/authorizationRules@2024-01-01' = {
  parent: printerStatusQueue
  name: 'agent-send-status'
  properties: {
    rights: [
      'Send'
    ]
  }
}

resource bcListenStatusRule 'Microsoft.ServiceBus/namespaces/queues/authorizationRules@2024-01-01' = {
  parent: printerStatusQueue
  name: 'bc-listen-status'
  properties: {
    rights: [
      'Listen'
    ]
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = if (enableDiagnostics) {
  name: logAnalyticsWorkspaceName
  location: location
  tags: commonTags
  properties: {
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    retentionInDays: diagnosticRetentionDays
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource serviceBusDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  name: 'send-to-log-analytics'
  scope: serviceBusNamespace
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'OperationalLogs'
        enabled: true
      }
      {
        category: 'DiagnosticErrorLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource blobDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  name: 'send-to-log-analytics'
  scope: blobService
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output serviceBusNamespaceName string = serviceBusNamespace.name
output serviceBusEndpoint string = serviceBusNamespace.properties.serviceBusEndpoint
output printJobsQueueName string = printJobsQueue.name
output printerStatusQueueName string = printerStatusQueue.name
output storageAccountName string = storageAccount.name
output blobServiceEndpoint string = storageAccount.properties.primaryEndpoints.blob
output printJobsContainerName string = printJobsContainer.name
output printJobsContainerUrl string = '${storageAccount.properties.primaryEndpoints.blob}${printJobsContainer.name}'
output logAnalyticsWorkspaceName string = enableDiagnostics ? logAnalyticsWorkspace.name : ''
output payloadRetentionDays int = payloadRetentionDays
output routingTenantId string = routingTenantId
output routingCompanyId string = routingCompanyId
output secretsEmitted bool = false
