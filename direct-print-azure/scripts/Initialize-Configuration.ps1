[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ResourceGroupName,

    [Parameter(Mandatory)]
    [string] $StationId,

    [ValidateSet('dev', 'sandbox', 'test', 'uat', 'prod')]
    [string] $EnvironmentName = 'sandbox',

    [string] $SubscriptionId,

    [ValidateRange(1, 365)]
    [int] $BlobSasValidityDays = 90,

    [string] $OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')

Assert-PowerShellVersion
Assert-AzureCli
Assert-ResourceGroupName -Name $ResourceGroupName
Assert-StationId -StationId $StationId
[void] (Select-AzureSubscription -SubscriptionId $SubscriptionId)
$stationSegments = $StationId.Split('.')
$routingTenantId = $stationSegments[0]
$routingCompanyId = $stationSegments[1]
$warehouseId = $stationSegments[2]
$stationCode = $stationSegments[3]

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) '.local'
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
[void] [System.IO.Directory]::CreateDirectory($OutputDirectory)

$deploymentName = "direct-print-$EnvironmentName"
$outputs = Get-DeploymentOutputs -ResourceGroupName $ResourceGroupName -DeploymentName $deploymentName

$requiredOutputs = @(
    'serviceBusNamespaceName',
    'storageAccountName',
    'blobServiceEndpoint',
    'printJobsContainerName',
    'printJobsQueueName',
    'printerStatusQueueName',
    'routingTenantId',
    'routingCompanyId'
)
foreach ($requiredOutput in $requiredOutputs) {
    if ((-not $outputs.Contains($requiredOutput)) -or [string]::IsNullOrWhiteSpace([string]$outputs[$requiredOutput])) {
        throw "Deployment '$deploymentName' does not contain required output '$requiredOutput'. Redeploy with Deploy.ps1."
    }
}

if (($routingTenantId -cne [string]$outputs.routingTenantId) -or
    ($routingCompanyId -cne [string]$outputs.routingCompanyId)) {
    throw "StationId routing scope '$routingTenantId.$routingCompanyId' does not match deployment scope '$($outputs.routingTenantId).$($outputs.routingCompanyId)'. Deploy a separate resource group/namespace for another BC company."
}

$namespaceName = [string]$outputs.serviceBusNamespaceName
$storageAccountName = [string]$outputs.storageAccountName
$blobEndpoint = ([string]$outputs.blobServiceEndpoint).TrimEnd('/')
$containerName = [string]$outputs.printJobsContainerName
$jobsQueueName = [string]$outputs.printJobsQueueName
$statusQueueName = [string]$outputs.printerStatusQueueName
$containerUrl = "$blobEndpoint/$containerName"

function Get-QueueConnectionString {
    param(
        [Parameter(Mandatory)][string] $QueueName,
        [Parameter(Mandatory)][string] $RuleName
    )

    $result = Invoke-AzureCli -Arguments @(
        'servicebus', 'queue', 'authorization-rule', 'keys', 'list',
        '--resource-group', $ResourceGroupName,
        '--namespace-name', $namespaceName,
        '--queue-name', $QueueName,
        '--name', $RuleName,
        '--query', 'primaryConnectionString',
        '--output', 'tsv',
        '--only-show-errors'
    )
    $connectionString = $result.StdOut
    if ([string]::IsNullOrWhiteSpace($connectionString)) {
        throw "Azure returned an empty connection string for $QueueName/$RuleName."
    }
    if (($connectionString -notmatch "SharedAccessKeyName=$([regex]::Escape($RuleName))([;]|$)") -or
        ($connectionString -notmatch "EntityPath=$([regex]::Escape($QueueName))([;]|$)")) {
        throw "Azure returned an unexpectedly scoped connection string for $QueueName/$RuleName."
    }
    return $connectionString
}

# These are queue-level connection strings. RootManageSharedAccessKey is never fetched.
$bcJobsSend = Get-QueueConnectionString -QueueName $jobsQueueName -RuleName 'bc-send-jobs'
$agentJobsListen = Get-QueueConnectionString -QueueName $jobsQueueName -RuleName 'agent-listen-jobs'
$agentStatusSend = Get-QueueConnectionString -QueueName $statusQueueName -RuleName 'agent-send-status'
$bcStatusListen = Get-QueueConnectionString -QueueName $statusQueueName -RuleName 'bc-listen-status'

$accountKeyResult = Invoke-AzureCli -Arguments @(
    'storage', 'account', 'keys', 'list',
    '--resource-group', $ResourceGroupName,
    '--account-name', $storageAccountName,
    '--query', '[0].value',
    '--output', 'tsv',
    '--only-show-errors'
)
$storageAccountKey = $accountKeyResult.StdOut
if ([string]::IsNullOrWhiteSpace($storageAccountKey)) {
    throw "Azure returned no key for storage account '$storageAccountName'."
}

$previousStorageAccount = [Environment]::GetEnvironmentVariable('AZURE_STORAGE_ACCOUNT', 'Process')
$previousStorageKey = [Environment]::GetEnvironmentVariable('AZURE_STORAGE_KEY', 'Process')
$startUtc = [DateTimeOffset]::UtcNow.AddMinutes(-5).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
$expiryUtc = [DateTimeOffset]::UtcNow.AddDays($BlobSasValidityDays).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")

try {
    # Environment variables avoid exposing the storage account key in command-line arguments.
    [Environment]::SetEnvironmentVariable('AZURE_STORAGE_ACCOUNT', $storageAccountName, 'Process')
    [Environment]::SetEnvironmentVariable('AZURE_STORAGE_KEY', $storageAccountKey, 'Process')

    $policyListResult = Invoke-AzureCli -Arguments @(
        'storage', 'container', 'policy', 'list',
        '--container-name', $containerName,
        '--auth-mode', 'key',
        '--output', 'json',
        '--only-show-errors'
    )
    $policies = $policyListResult.StdOut | ConvertFrom-Json -Depth 10
    $existingPolicyNames = @(
        $policies.PSObject.Properties |
            ForEach-Object { $_.Name }
    )

    foreach ($policy in @(
        @{ Name = 'bc-upload'; Permissions = 'cw' },
        @{ Name = 'agent-read'; Permissions = 'r' }
    )) {
        $verb = if ($existingPolicyNames -contains $policy.Name) { 'update' } else { 'create' }
        [void] (Invoke-AzureCli -Arguments @(
            'storage', 'container', 'policy', $verb,
            '--container-name', $containerName,
            '--name', $policy.Name,
            '--permissions', $policy.Permissions,
            '--start', $startUtc,
            '--expiry', $expiryUtc,
            '--auth-mode', 'key',
            '--output', 'none',
            '--only-show-errors'
        ))
    }

    $bcBlobSasResult = Invoke-AzureCli -Arguments @(
        'storage', 'container', 'generate-sas',
        '--name', $containerName,
        '--policy-name', 'bc-upload',
        '--https-only',
        '--auth-mode', 'key',
        '--output', 'tsv',
        '--only-show-errors'
    )
    $agentBlobSasResult = Invoke-AzureCli -Arguments @(
        'storage', 'container', 'generate-sas',
        '--name', $containerName,
        '--policy-name', 'agent-read',
        '--https-only',
        '--auth-mode', 'key',
        '--output', 'tsv',
        '--only-show-errors'
    )
    $bcBlobWriteSas = $bcBlobSasResult.StdOut.TrimStart('?')
    $agentBlobReadSas = $agentBlobSasResult.StdOut.TrimStart('?')
}
finally {
    $storageAccountKey = $null
    [Environment]::SetEnvironmentVariable('AZURE_STORAGE_ACCOUNT', $previousStorageAccount, 'Process')
    [Environment]::SetEnvironmentVariable('AZURE_STORAGE_KEY', $previousStorageKey, 'Process')
}

if (($bcBlobWriteSas -notmatch '(^|&)sig=') -or ($agentBlobReadSas -notmatch '(^|&)sig=')) {
    throw 'One or both Blob SAS tokens are invalid. No configuration was written.'
}

$generatedAt = [DateTimeOffset]::UtcNow.ToString('O')
$bcSecretsPath = Join-Path $OutputDirectory 'business-central.runtime.secrets.json'
$agentSecretsPath = Join-Path $OutputDirectory 'print-agent.runtime.secrets.json'
$templatePath = Join-Path $OutputDirectory 'client-config.template.json'

$commonSecretProperties = [ordered]@{
    schemaVersion = 1
    generatedAtUtc = $generatedAt
    blobSasExpiresAtUtc = $expiryUtc
    stationId = $StationId
    routing = [ordered]@{
        deploymentScope = 'single-bc-environment-company'
        tenantId = $routingTenantId
        companyId = $routingCompanyId
        warehouseId = $warehouseId
        stationCode = $stationCode
    }
}

$bcSecretDocument = [ordered]@{}
foreach ($property in $commonSecretProperties.GetEnumerator()) {
    $bcSecretDocument[$property.Key] = $property.Value
}
$bcSecretDocument.businessCentral = [ordered]@{
    printJobsSendConnectionString = $bcJobsSend
    printerStatusListenConnectionString = $bcStatusListen
    blobContainerUrl = $containerUrl
    blobCreateWriteSasToken = $bcBlobWriteSas
}

$agentSecretDocument = [ordered]@{}
foreach ($property in $commonSecretProperties.GetEnumerator()) {
    $agentSecretDocument[$property.Key] = $property.Value
}
$agentSecretDocument.agent = [ordered]@{
    printJobsListenConnectionString = $agentJobsListen
    printerStatusSendConnectionString = $agentStatusSend
    blobAccountName = $storageAccountName
    blobContainerName = $containerName
    blobReadSasToken = $agentBlobReadSas
}

# Keep the two documents separate: a workstation never receives BC's
# Send/Listen credentials and BC never receives the agent's Listen/Send keys.

$templateDocument = [ordered]@{
    schemaVersion = 1
    stationId = $StationId
    routing = [ordered]@{
        deploymentScope = 'single-bc-environment-company'
        tenantId = $routingTenantId
        companyId = $routingCompanyId
        warehouseId = $warehouseId
        stationCode = $stationCode
        exactSessionMatchRequired = $true
        sessionIdFormat = 'TENANT.COMPANY.WAREHOUSE.STATION'
        jobMessageCarries = 'blobName only; never a SAS token or arbitrary URL'
        statusQueueConstraint = 'non-session queue; exactly one BC environment/company status consumer'
    }
    azure = [ordered]@{
        serviceBus = [ordered]@{
            namespaceName = $namespaceName
            printJobsQueueName = $jobsQueueName
            printerStatusQueueName = $statusQueueName
            businessCentralJobsSendConnectionString = '${BCWMS_SB_JOBS_SEND}'
            businessCentralStatusListenConnectionString = '${BCWMS_SB_STATUS_LISTEN}'
            agentJobsListenConnectionString = '${BCWMS_SB_JOBS_LISTEN}'
            agentStatusSendConnectionString = '${BCWMS_SB_STATUS_SEND}'
            transport = 'AmqpWebSockets'
            tlsMinimum = '1.2'
        }
        blob = [ordered]@{
            accountName = $storageAccountName
            containerName = $containerName
            containerUrl = $containerUrl
            businessCentralCreateWriteSasToken = '${BCWMS_BLOB_WRITE_SAS}'
            agentReadSasToken = '${BCWMS_BLOB_READ_SAS}'
            rejectForeignHosts = $true
            rejectForeignContainers = $true
        }
    }
}

Write-SecretJsonFileAtomic -Path $bcSecretsPath -Value $bcSecretDocument
Write-SecretJsonFileAtomic -Path $agentSecretsPath -Value $agentSecretDocument
Write-JsonFileAtomic -Path $templatePath -Value $templateDocument

# Deliberately never print the object, connection strings, account key, or SAS tokens.
Write-Host 'Scoped credentials generated successfully.' -ForegroundColor Green
Write-Host "BC secret file (restricted permissions, gitignored): $bcSecretsPath"
Write-Host "Agent secret file (restricted permissions, gitignored): $agentSecretsPath"
Write-Host "Sanitized template: $templatePath"
Write-Host "Blob SAS expiry (UTC): $expiryUtc"
Write-Warning 'Import each scoped file only into its named target, then delete it or move it to an approved secret store.'

$bcJobsSend = $null
$agentJobsListen = $null
$agentStatusSend = $null
$bcStatusListen = $null
$bcBlobWriteSas = $null
$agentBlobReadSas = $null
$stationSegments = $null
