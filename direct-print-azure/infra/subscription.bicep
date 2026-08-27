targetScope = 'subscription'

metadata name = 'BC WMS direct print subscription deployment'
metadata description = 'Creates the dedicated resource group and deploys the group-scope direct print template. Enables a side-effect-free subscription what-if.'

@minLength(1)
@maxLength(90)
param resourceGroupName string

@minLength(2)
@maxLength(18)
param namePrefix string

@minLength(1)
@maxLength(32)
param routingTenantId string

@minLength(1)
@maxLength(32)
param routingCompanyId string

@allowed([
  'dev'
  'sandbox'
  'test'
  'uat'
  'prod'
])
param environmentName string = 'sandbox'

param location string

@minValue(8)
@maxValue(30)
param payloadRetentionDays int = 14

@minValue(30)
@maxValue(730)
param diagnosticRetentionDays int = 30

param enableDiagnostics bool = true

param tags object = {}

var resourceGroupTags = union(tags, {
  application: 'bc-wms-direct-print'
  environment: environmentName
  managedBy: 'direct-print-azure'
  routingScope: '${routingTenantId}.${routingCompanyId}'
})

resource directPrintResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: resourceGroupTags
}

module directPrint 'main.bicep' = {
  name: 'direct-print-${environmentName}'
  scope: directPrintResourceGroup
  params: {
    namePrefix: namePrefix
    routingTenantId: routingTenantId
    routingCompanyId: routingCompanyId
    environmentName: environmentName
    location: location
    payloadRetentionDays: payloadRetentionDays
    diagnosticRetentionDays: diagnosticRetentionDays
    enableDiagnostics: enableDiagnostics
    tags: tags
  }
}

output resourceGroupName string = directPrintResourceGroup.name
output serviceBusNamespaceName string = directPrint.outputs.serviceBusNamespaceName
output serviceBusEndpoint string = directPrint.outputs.serviceBusEndpoint
output printJobsQueueName string = directPrint.outputs.printJobsQueueName
output printerStatusQueueName string = directPrint.outputs.printerStatusQueueName
output storageAccountName string = directPrint.outputs.storageAccountName
output blobServiceEndpoint string = directPrint.outputs.blobServiceEndpoint
output printJobsContainerName string = directPrint.outputs.printJobsContainerName
output printJobsContainerUrl string = directPrint.outputs.printJobsContainerUrl
output logAnalyticsWorkspaceName string = directPrint.outputs.logAnalyticsWorkspaceName
output payloadRetentionDays int = directPrint.outputs.payloadRetentionDays
output routingTenantId string = directPrint.outputs.routingTenantId
output routingCompanyId string = directPrint.outputs.routingCompanyId
output secretsEmitted bool = false
