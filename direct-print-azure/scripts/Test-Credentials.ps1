[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ResourceGroupName,

    [string] $BusinessCentralSecretsPath,

    [string] $PrintAgentSecretsPath,

    [string] $SubscriptionId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')

Assert-PowerShellVersion
Assert-AzureCli
Assert-ResourceGroupName -Name $ResourceGroupName
[void] (Select-AzureSubscription -SubscriptionId $SubscriptionId)

if ([string]::IsNullOrWhiteSpace($BusinessCentralSecretsPath)) {
    $BusinessCentralSecretsPath = Join-Path (Split-Path -Parent $PSScriptRoot) '.local/business-central.runtime.secrets.json'
}
if ([string]::IsNullOrWhiteSpace($PrintAgentSecretsPath)) {
    $PrintAgentSecretsPath = Join-Path (Split-Path -Parent $PSScriptRoot) '.local/print-agent.runtime.secrets.json'
}
$BusinessCentralSecretsPath = [System.IO.Path]::GetFullPath($BusinessCentralSecretsPath)
$PrintAgentSecretsPath = [System.IO.Path]::GetFullPath($PrintAgentSecretsPath)
foreach ($secretPath in @($BusinessCentralSecretsPath, $PrintAgentSecretsPath)) {
    if (-not (Test-Path -LiteralPath $secretPath -PathType Leaf)) {
        throw "Secret file not found: $secretPath. Run Initialize-Configuration.ps1 first."
    }
}

$bcCredentials = Get-Content -LiteralPath $BusinessCentralSecretsPath -Raw | ConvertFrom-Json -Depth 20
$agentCredentials = Get-Content -LiteralPath $PrintAgentSecretsPath -Raw | ConvertFrom-Json -Depth 20
$stationId = [string]$bcCredentials.stationId
Assert-StationId -StationId $stationId
if ($stationId -cne [string]$agentCredentials.stationId) {
    throw 'The BC and print-agent secret files belong to different Station IDs.'
}

$storageAccountName = [string]$agentCredentials.agent.blobAccountName
$containerName = [string]$agentCredentials.agent.blobContainerName
$bcWriteSas = ([string]$bcCredentials.businessCentral.blobCreateWriteSasToken).TrimStart('?')
$agentReadSas = ([string]$agentCredentials.agent.blobReadSasToken).TrimStart('?')
if ([string]::IsNullOrWhiteSpace($storageAccountName) -or
    [string]::IsNullOrWhiteSpace($containerName) -or
    ($bcWriteSas -notmatch '(^|&)sig=') -or
    ($agentReadSas -notmatch '(^|&)sig=')) {
    throw 'The secret file does not contain valid scoped Blob credentials.'
}

$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("bcwms-credential-test-$([guid]::NewGuid().ToString('N'))")
[void] [System.IO.Directory]::CreateDirectory($temporaryDirectory)
$sourcePath = Join-Path $temporaryDirectory 'source.txt'
$downloadPath = Join-Path $temporaryDirectory 'download.txt'
$deniedUploadPath = Join-Path $temporaryDirectory 'denied.txt'
$testId = [guid]::NewGuid().ToString('N')
$blobName = "healthchecks/$stationId/$testId.txt"
$utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($sourcePath, "bc-wms-direct-print:$testId", $utf8WithoutBom)
[System.IO.File]::WriteAllText($deniedUploadPath, 'this upload must be denied', $utf8WithoutBom)

$previousStorageAccount = [Environment]::GetEnvironmentVariable('AZURE_STORAGE_ACCOUNT', 'Process')
$previousStorageSas = [Environment]::GetEnvironmentVariable('AZURE_STORAGE_SAS_TOKEN', 'Process')
$previousStorageKey = [Environment]::GetEnvironmentVariable('AZURE_STORAGE_KEY', 'Process')
$blobCreated = $false

try {
    [Environment]::SetEnvironmentVariable('AZURE_STORAGE_ACCOUNT', $storageAccountName, 'Process')
    [Environment]::SetEnvironmentVariable('AZURE_STORAGE_KEY', $null, 'Process')

    # BC token: create/write must succeed.
    [Environment]::SetEnvironmentVariable('AZURE_STORAGE_SAS_TOKEN', $bcWriteSas, 'Process')
    [void] (Invoke-AzureCli -Arguments @(
        'storage', 'blob', 'upload',
        '--container-name', $containerName,
        '--name', $blobName,
        '--file', $sourcePath,
        '--overwrite', 'true',
        '--auth-mode', 'key',
        '--output', 'none',
        '--only-show-errors'
    ))
    $blobCreated = $true

    # BC write token must not be able to read its uploaded payload.
    $unexpectedBcRead = Invoke-AzureCli -Arguments @(
        'storage', 'blob', 'download',
        '--container-name', $containerName,
        '--name', $blobName,
        '--file', (Join-Path $temporaryDirectory 'bc-must-not-read.txt'),
        '--auth-mode', 'key',
        '--output', 'none',
        '--only-show-errors'
    ) -AllowFailure
    if ($unexpectedBcRead.ExitCode -eq 0) {
        throw 'Least-privilege test failed: the BC create/write SAS can also read blobs.'
    }

    # Agent token: read must succeed and preserve the payload.
    [Environment]::SetEnvironmentVariable('AZURE_STORAGE_SAS_TOKEN', $agentReadSas, 'Process')
    [void] (Invoke-AzureCli -Arguments @(
        'storage', 'blob', 'download',
        '--container-name', $containerName,
        '--name', $blobName,
        '--file', $downloadPath,
        '--auth-mode', 'key',
        '--output', 'none',
        '--only-show-errors'
    ))
    $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    $downloadHash = (Get-FileHash -LiteralPath $downloadPath -Algorithm SHA256).Hash
    if ($sourceHash -cne $downloadHash) {
        throw 'Blob integrity test failed: downloaded bytes differ from uploaded bytes.'
    }

    # Agent read token must not be able to create or overwrite blobs.
    $unexpectedAgentWrite = Invoke-AzureCli -Arguments @(
        'storage', 'blob', 'upload',
        '--container-name', $containerName,
        '--name', "healthchecks/$stationId/$testId-denied.txt",
        '--file', $deniedUploadPath,
        '--overwrite', 'true',
        '--auth-mode', 'key',
        '--output', 'none',
        '--only-show-errors'
    ) -AllowFailure
    if ($unexpectedAgentWrite.ExitCode -eq 0) {
        throw 'Least-privilege test failed: the agent read SAS can also write blobs.'
    }

    Write-Host 'Blob credential and byte-integrity tests passed.' -ForegroundColor Green
}
finally {
    if ($blobCreated) {
        try {
            $accountKeyResult = Invoke-AzureCli -Arguments @(
                'storage', 'account', 'keys', 'list',
                '--resource-group', $ResourceGroupName,
                '--account-name', $storageAccountName,
                '--query', '[0].value',
                '--output', 'tsv',
                '--only-show-errors'
            )
            [Environment]::SetEnvironmentVariable('AZURE_STORAGE_SAS_TOKEN', $null, 'Process')
            [Environment]::SetEnvironmentVariable('AZURE_STORAGE_KEY', $accountKeyResult.StdOut, 'Process')
            [void] (Invoke-AzureCli -Arguments @(
                'storage', 'blob', 'delete',
                '--container-name', $containerName,
                '--name', $blobName,
                '--auth-mode', 'key',
                '--output', 'none',
                '--only-show-errors'
            ))
        }
        catch {
            Write-Warning "Credential test blob could not be deleted. Lifecycle cleanup will remove it: $blobName"
        }
    }

    [Environment]::SetEnvironmentVariable('AZURE_STORAGE_ACCOUNT', $previousStorageAccount, 'Process')
    [Environment]::SetEnvironmentVariable('AZURE_STORAGE_SAS_TOKEN', $previousStorageSas, 'Process')
    [Environment]::SetEnvironmentVariable('AZURE_STORAGE_KEY', $previousStorageKey, 'Process')
    $bcWriteSas = $null
    $agentReadSas = $null
    $bcCredentials = $null
    $agentCredentials = $null
    if (Test-Path -LiteralPath $temporaryDirectory) {
        Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
    }
}
