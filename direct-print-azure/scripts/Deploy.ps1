[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory)]
    [string] $ResourceGroupName,

    [Parameter(Mandatory)]
    [string] $NamePrefix,

    [Parameter(Mandatory)]
    [string] $TenantId,

    [Parameter(Mandatory)]
    [string] $CompanyId,

    [ValidateSet('dev', 'sandbox', 'test', 'uat', 'prod')]
    [string] $EnvironmentName = 'sandbox',

    [string] $Location = 'westeurope',

    [string] $SubscriptionId,

    [ValidateRange(8, 30)]
    [int] $PayloadRetentionDays = 14,

    [ValidateRange(30, 730)]
    [int] $DiagnosticRetentionDays = 30,

    [bool] $EnableDiagnostics = $true,

    [switch] $WhatIfOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')

Assert-PowerShellVersion
Assert-AzureCli
Assert-ResourceGroupName -Name $ResourceGroupName
Assert-NamePrefix -Name $NamePrefix
Assert-RoutingSegment -Value $TenantId -Label 'TenantId'
Assert-RoutingSegment -Value $CompanyId -Label 'CompanyId'

$account = Select-AzureSubscription -SubscriptionId $SubscriptionId
Assert-AzureLocation -Location $Location

$groupDeploymentName = "direct-print-$EnvironmentName"
$resourceGroupHashBytes = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($ResourceGroupName.ToLowerInvariant()))
$resourceGroupHash = ([Convert]::ToHexString($resourceGroupHashBytes)).Substring(0, 8).ToLowerInvariant()
$subscriptionDeploymentName = "direct-print-$EnvironmentName-$NamePrefix-$resourceGroupHash"
$bicepPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'infra/subscription.bicep'
if (-not (Test-Path -LiteralPath $bicepPath -PathType Leaf)) {
    throw "Bicep template not found: $bicepPath"
}

$groupExistsResult = Invoke-AzureCli -Arguments @('group', 'exists', '--name', $ResourceGroupName, '--output', 'tsv', '--only-show-errors')
$groupExists = $groupExistsResult.StdOut -eq 'true'

if ($groupExists) {
    $groupResult = Invoke-AzureCli -Arguments @('group', 'show', '--name', $ResourceGroupName, '--output', 'json', '--only-show-errors')
    $group = $groupResult.StdOut | ConvertFrom-Json -Depth 10
    $managedByTag = [string](Get-OptionalPropertyValue -InputObject $group.tags -Name 'managedBy')
    $routingScopeTag = [string](Get-OptionalPropertyValue -InputObject $group.tags -Name 'routingScope')
    if ($managedByTag -ne 'direct-print-azure') {
        throw "Resource group '$ResourceGroupName' already exists but is not owned by direct-print-azure. Use a new dedicated resource group."
    }
    if ((-not [string]::IsNullOrWhiteSpace($routingScopeTag)) -and ($routingScopeTag -cne "$TenantId.$CompanyId")) {
        throw "Resource group '$ResourceGroupName' is already scoped to '$routingScopeTag', not '$TenantId.$CompanyId'. Use a separate resource group/namespace for another BC company."
    }
    if ($group.location -ne $Location) {
        throw "Resource group '$ResourceGroupName' is in '$($group.location)', not '$Location'. Re-run with -Location '$($group.location)'."
    }
}

$parameterDocument = [ordered]@{
    '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
    contentVersion = '1.0.0.0'
    parameters = [ordered]@{
        resourceGroupName = @{ value = $ResourceGroupName }
        namePrefix = @{ value = $NamePrefix }
        routingTenantId = @{ value = $TenantId }
        routingCompanyId = @{ value = $CompanyId }
        environmentName = @{ value = $EnvironmentName }
        location = @{ value = $Location }
        payloadRetentionDays = @{ value = $PayloadRetentionDays }
        diagnosticRetentionDays = @{ value = $DiagnosticRetentionDays }
        enableDiagnostics = @{ value = $EnableDiagnostics }
        tags = @{ value = [ordered]@{ owner = 'wms-team'; purpose = 'direct-print' } }
    }
}

$temporaryParametersPath = Join-Path ([System.IO.Path]::GetTempPath()) ("direct-print-parameters-$([guid]::NewGuid().ToString('N')).json")
$utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)

try {
    [System.IO.File]::WriteAllText(
        $temporaryParametersPath,
        ($parameterDocument | ConvertTo-Json -Depth 10) + [Environment]::NewLine,
        $utf8WithoutBom
    )

    $operation = if ($WhatIfOnly) { 'what-if' } else { 'create' }
    $arguments = @(
        'deployment', 'sub', $operation,
        '--location', $Location,
        '--name', $subscriptionDeploymentName,
        '--template-file', $bicepPath,
        '--parameters', "@$temporaryParametersPath",
        '--only-show-errors'
    )

    if ($WhatIfOnly) {
        $arguments += @('--output', 'table')
    }
    else {
        $arguments += @('--query', 'properties.outputs', '--output', 'json')
    }

    if ($PSCmdlet.ShouldProcess("subscription deployment $subscriptionDeploymentName targeting $ResourceGroupName", $operation)) {
        $deploymentResult = Invoke-AzureCli -Arguments $arguments
        if ($WhatIfOnly) {
            Write-Host $deploymentResult.StdOut
            Write-Host 'Subscription-scope what-if completed. No Azure resource was changed.' -ForegroundColor Green
            return
        }

        $rawOutputs = $deploymentResult.StdOut | ConvertFrom-Json -Depth 20
        $safeOutputs = [ordered]@{}
        foreach ($property in $rawOutputs.PSObject.Properties) {
            $safeOutputs[$property.Name] = $property.Value.value
        }

        $localDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) '.local'
        $safeOutputPath = Join-Path $localDirectory 'deployment.outputs.json'
        Write-JsonFileAtomic -Path $safeOutputPath -Value ([ordered]@{
            generatedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
            subscriptionId = $account.id
            resourceGroupName = $ResourceGroupName
            subscriptionDeploymentName = $subscriptionDeploymentName
            resourceGroupDeploymentName = $groupDeploymentName
            outputs = $safeOutputs
        })

        Write-Host "Deployment completed: $subscriptionDeploymentName" -ForegroundColor Green
        Write-Host "Non-secret outputs: $safeOutputPath"
        Write-Host 'Next: run Initialize-Configuration.ps1 to create revocable client credentials.'
    }
}
finally {
    $resourceGroupHashBytes = $null
    if (Test-Path -LiteralPath $temporaryParametersPath) {
        Remove-Item -LiteralPath $temporaryParametersPath -Force
    }
}
