[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ResourceGroupName,

    [ValidateSet('dev', 'sandbox', 'test', 'uat', 'prod')]
    [string] $EnvironmentName = 'sandbox',

    [string] $SubscriptionId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')

Assert-PowerShellVersion
Assert-AzureCli
Assert-ResourceGroupName -Name $ResourceGroupName
$account = Select-AzureSubscription -SubscriptionId $SubscriptionId

$deploymentName = "direct-print-$EnvironmentName"
$outputs = Get-DeploymentOutputs -ResourceGroupName $ResourceGroupName -DeploymentName $deploymentName
$namespaceName = [string]$outputs.serviceBusNamespaceName
$storageAccountName = [string]$outputs.storageAccountName
$jobsQueueName = [string]$outputs.printJobsQueueName
$statusQueueName = [string]$outputs.printerStatusQueueName
$containerName = [string]$outputs.printJobsContainerName
$failures = [System.Collections.Generic.List[string]]::new()

$groupResult = Invoke-AzureCli -Arguments @('group', 'show', '--name', $ResourceGroupName, '--output', 'json', '--only-show-errors')
$group = $groupResult.StdOut | ConvertFrom-Json -Depth 10
$routingScopeTag = [string](Get-OptionalPropertyValue -InputObject $group.tags -Name 'routingScope')

function Assert-Equal {
    param([string] $Name, $Actual, $Expected)
    if ($Actual -ne $Expected) {
        $failures.Add("${Name}: expected '$Expected', received '$Actual'.")
    }
}

Assert-Equal 'Resource-group routing scope' $routingScopeTag "$($outputs.routingTenantId).$($outputs.routingCompanyId)"

$namespaceResult = Invoke-AzureCli -Arguments @(
    'servicebus', 'namespace', 'show',
    '--resource-group', $ResourceGroupName,
    '--name', $namespaceName,
    '--output', 'json',
    '--only-show-errors'
)
$namespace = $namespaceResult.StdOut | ConvertFrom-Json -Depth 20
Assert-Equal 'Service Bus SKU' $namespace.sku.name 'Standard'
Assert-Equal 'Service Bus minimum TLS' $namespace.minimumTlsVersion '1.2'
Assert-Equal 'Service Bus public network' $namespace.publicNetworkAccess 'Enabled'

$jobsResult = Invoke-AzureCli -Arguments @(
    'servicebus', 'queue', 'show',
    '--resource-group', $ResourceGroupName,
    '--namespace-name', $namespaceName,
    '--name', $jobsQueueName,
    '--output', 'json',
    '--only-show-errors'
)
$jobsQueue = $jobsResult.StdOut | ConvertFrom-Json -Depth 20
Assert-Equal 'Jobs queue requires sessions' $jobsQueue.requiresSession $true
Assert-Equal 'Jobs queue duplicate detection' $jobsQueue.requiresDuplicateDetection $true
Assert-Equal 'Jobs queue max delivery count' $jobsQueue.maxDeliveryCount 10
Assert-Equal 'Jobs queue dead-letters expired messages' $jobsQueue.deadLetteringOnMessageExpiration $true
Assert-Equal 'Jobs queue message TTL' $jobsQueue.defaultMessageTimeToLive 'P7D'

$statusResult = Invoke-AzureCli -Arguments @(
    'servicebus', 'queue', 'show',
    '--resource-group', $ResourceGroupName,
    '--namespace-name', $namespaceName,
    '--name', $statusQueueName,
    '--output', 'json',
    '--only-show-errors'
)
$statusQueue = $statusResult.StdOut | ConvertFrom-Json -Depth 20
Assert-Equal 'Status queue requires sessions' $statusQueue.requiresSession $false
Assert-Equal 'Status queue duplicate detection' $statusQueue.requiresDuplicateDetection $true
Assert-Equal 'Status queue message TTL' $statusQueue.defaultMessageTimeToLive 'P7D'
Assert-Equal 'Status queue max delivery count' $statusQueue.maxDeliveryCount 10

$expectedRules = @(
    @{ Queue = $jobsQueueName; Name = 'bc-send-jobs'; Rights = @('Send') },
    @{ Queue = $jobsQueueName; Name = 'agent-listen-jobs'; Rights = @('Listen') },
    @{ Queue = $statusQueueName; Name = 'agent-send-status'; Rights = @('Send') },
    @{ Queue = $statusQueueName; Name = 'bc-listen-status'; Rights = @('Listen') }
)
foreach ($expectedRule in $expectedRules) {
    $ruleResult = Invoke-AzureCli -Arguments @(
        'servicebus', 'queue', 'authorization-rule', 'show',
        '--resource-group', $ResourceGroupName,
        '--namespace-name', $namespaceName,
        '--queue-name', $expectedRule.Queue,
        '--name', $expectedRule.Name,
        '--output', 'json',
        '--only-show-errors'
    )
    $rule = $ruleResult.StdOut | ConvertFrom-Json -Depth 10
    $actualRights = @($rule.rights | Sort-Object) -join ','
    $wantedRights = @($expectedRule.Rights | Sort-Object) -join ','
    Assert-Equal "Authorization rule $($expectedRule.Queue)/$($expectedRule.Name)" $actualRights $wantedRights
}

$storageResult = Invoke-AzureCli -Arguments @(
    'storage', 'account', 'show',
    '--resource-group', $ResourceGroupName,
    '--name', $storageAccountName,
    '--output', 'json',
    '--only-show-errors'
)
$storage = $storageResult.StdOut | ConvertFrom-Json -Depth 20
Assert-Equal 'Storage minimum TLS' $storage.minimumTlsVersion 'TLS1_2'
Assert-Equal 'Storage HTTPS-only' $storage.enableHttpsTrafficOnly $true
Assert-Equal 'Storage allows public blobs' $storage.allowBlobPublicAccess $false

$containerResult = Invoke-AzureCli -Arguments @(
    'storage', 'container-rm', 'show',
    '--resource-group', $ResourceGroupName,
    '--storage-account', $storageAccountName,
    '--name', $containerName,
    '--output', 'json',
    '--only-show-errors'
)
$container = $containerResult.StdOut | ConvertFrom-Json -Depth 10
if (($null -ne $container.publicAccess) -and ([string]$container.publicAccess -ne 'None')) {
    $failures.Add("Blob container public access: expected private/None, received '$($container.publicAccess)'.")
}

$lifecycleResult = Invoke-AzureCli -Arguments @(
    'storage', 'account', 'management-policy', 'show',
    '--resource-group', $ResourceGroupName,
    '--account-name', $storageAccountName,
    '--output', 'json',
    '--only-show-errors'
)
$lifecycle = $lifecycleResult.StdOut | ConvertFrom-Json -Depth 30
$cleanupRule = @($lifecycle.policy.rules | Where-Object { $_.name -eq 'delete-expired-print-payloads' })
Assert-Equal 'Blob lifecycle cleanup rule count' $cleanupRule.Count 1
if ($cleanupRule.Count -eq 1) {
    $configuredRetentionDays = [int]$outputs.payloadRetentionDays
    if ($configuredRetentionDays -lt 8) {
        $failures.Add("Blob payload retention must outlive the 7-day jobs queue TTL; received '$configuredRetentionDays' days.")
    }
    Assert-Equal 'Blob lifecycle payload retention' $cleanupRule[0].definition.actions.baseBlob.delete.daysAfterModificationGreaterThan $configuredRetentionDays
}

if ($outputs.Contains('logAnalyticsWorkspaceName') -and
    (-not [string]::IsNullOrWhiteSpace([string]$outputs.logAnalyticsWorkspaceName))) {
    $diagnosticResourceIds = @(
        "/subscriptions/$($account.id)/resourceGroups/$ResourceGroupName/providers/Microsoft.ServiceBus/namespaces/$namespaceName",
        "/subscriptions/$($account.id)/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/blobServices/default"
    )
    foreach ($diagnosticResourceId in $diagnosticResourceIds) {
        $diagnosticResult = Invoke-AzureCli -Arguments @(
            'monitor', 'diagnostic-settings', 'list',
            '--resource', $diagnosticResourceId,
            # Azure CLI returns this command as a top-level array. Querying the
            # REST envelope's old `value` property yields null on current CLI
            # versions and makes length() fail before validation can finish.
            '--query', "[?name=='send-to-log-analytics'] | length(@)",
            '--output', 'tsv',
            '--only-show-errors'
        )
        Assert-Equal "Diagnostic setting $diagnosticResourceId" $diagnosticResult.StdOut '1'
    }
}

if ($failures.Count -gt 0) {
    $details = $failures -join [Environment]::NewLine
    throw "Infrastructure validation failed:`n$details"
}

Write-Host 'Infrastructure validation passed.' -ForegroundColor Green
Write-Host 'This validates Azure resources and least-privilege policies; physical printing still requires the BC and Windows-agent end-to-end test.'
