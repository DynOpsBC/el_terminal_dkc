using './main.bicep'

// Safe sandbox defaults. Resource names are made globally unique by main.bicep.
param namePrefix = 'dopwms'
param routingTenantId = 'DOPS'
param routingCompanyId = 'CONTOSO'
param environmentName = 'sandbox'
param payloadRetentionDays = 14
param diagnosticRetentionDays = 30
param enableDiagnostics = true
param tags = {
  owner: 'wms-team'
  purpose: 'direct-print-sandbox'
}
