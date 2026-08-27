[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)]
    [string] $FilePath,

    [Parameter(Mandatory)]
    [string] $PrinterId,

    [Parameter(Mandatory)]
    [string] $PrinterName,

    [ValidateSet('Auto', 'PDF', 'ZPL', 'ESCPOS', 'RAW')]
    [string] $Format = 'Auto',

    [ValidateRange(1, 10)]
    [int] $Copies = 1,

    [guid] $JobId = [guid]::NewGuid(),

    [string] $StationId,

    [string] $SecretsPath,

    [switch] $DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')

Assert-PowerShellVersion
Assert-AzureCli

$FilePath = [System.IO.Path]::GetFullPath($FilePath)
if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
    throw "Print payload not found: $FilePath"
}
$fileInfo = Get-Item -LiteralPath $FilePath
if (($fileInfo.Length -le 0) -or ($fileInfo.Length -gt 50MB)) {
    throw "Print payload must be 1 byte through 50 MiB; received $($fileInfo.Length) bytes."
}
if ($PrinterId -notmatch '^P[0-9A-F]{16}\z') {
    throw "Invalid PrinterId '$PrinterId'. Copy the exact persisted logical ID from the agent UI (P + 16 uppercase hexadecimal characters)."
}
if ([string]::IsNullOrWhiteSpace($PrinterName) -or ($PrinterName.Length -gt 260) -or ($PrinterName -match '[\x00-\x1F\x7F]')) {
    throw 'PrinterName must contain 1-260 printable characters and no control characters.'
}

$extension = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()
if ($Format -eq 'Auto') {
    $Format = switch ($extension) {
        '.pdf' { 'PDF' }
        '.zpl' { 'ZPL' }
        default { throw "Format could not be inferred from '$extension'. Specify -Format PDF, ZPL, ESCPOS or RAW." }
    }
}
if (($Format -eq 'PDF') -and ($extension -ne '.pdf')) {
    throw 'PDF smoke-test payload must use the .pdf extension.'
}

if ([string]::IsNullOrWhiteSpace($SecretsPath)) {
    $SecretsPath = Join-Path (Split-Path -Parent $PSScriptRoot) '.local/business-central.runtime.secrets.json'
}
$SecretsPath = [System.IO.Path]::GetFullPath($SecretsPath)
$credentials = $null
if (Test-Path -LiteralPath $SecretsPath -PathType Leaf) {
    $credentials = Get-Content -LiteralPath $SecretsPath -Raw | ConvertFrom-Json -Depth 20
    $configuredStationId = [string]$credentials.stationId
    if ([string]::IsNullOrWhiteSpace($StationId)) {
        $StationId = $configuredStationId
    }
    elseif ($StationId -cne $configuredStationId) {
        throw "StationId '$StationId' does not exactly match the credential scope '$configuredStationId'."
    }
}
elseif (-not $DryRun) {
    throw "Secret file not found: $SecretsPath. Run Initialize-Configuration.ps1 first."
}

if ([string]::IsNullOrWhiteSpace($StationId)) {
    throw '-StationId is required when -DryRun is used without a secret file.'
}
Assert-StationId -StationId $StationId
$stationSegments = $StationId.Split('.')
$jobIdText = $JobId.ToString('D').ToLowerInvariant()
$blobExtension = switch ($Format) {
    'PDF' { 'pdf' }
    'ZPL' { 'zpl' }
    'ESCPOS' { 'escpos' }
    default { 'raw' }
}
$blobName = "jobs/$StationId/$jobIdText.$blobExtension"
$payloadSha256 = (Get-FileHash -LiteralPath $FilePath -Algorithm SHA256).Hash.ToUpperInvariant()
$createdAtUtc = [DateTimeOffset]::UtcNow.ToString('O')

$job = [ordered]@{
    schemaVersion = 1
    jobId = $jobIdText
    tenantId = $stationSegments[0]
    companyId = $stationSegments[1]
    stationId = $StationId
    printerId = $PrinterId
    printerName = $PrinterName
    format = $Format
    copies = $Copies
    blobName = $blobName
    payloadSha256 = $payloadSha256
    payloadSize = [long]$fileInfo.Length
    createdAtUtc = $createdAtUtc
}

if ($DryRun) {
    Write-Host 'Dry-run only: no Blob was uploaded and no Service Bus message was sent.' -ForegroundColor Yellow
    $job | ConvertTo-Json -Depth 10
    return
}

if (-not $PSCmdlet.ShouldProcess("station $StationId / printer $PrinterId", "Upload Blob and enqueue smoke-test job $jobIdText")) {
    Write-Host 'No Blob was uploaded and no Service Bus message was sent.' -ForegroundColor Yellow
    $job | ConvertTo-Json -Depth 10
    return
}

function ConvertFrom-ServiceBusConnectionString {
    param([Parameter(Mandatory)][string] $ConnectionString)

    $values = @{}
    foreach ($part in $ConnectionString.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)) {
        $separator = $part.IndexOf('=')
        if ($separator -le 0) {
            continue
        }
        $values[$part.Substring(0, $separator)] = $part.Substring($separator + 1)
    }
    foreach ($key in @('Endpoint', 'SharedAccessKeyName', 'SharedAccessKey', 'EntityPath')) {
        if ((-not $values.ContainsKey($key)) -or [string]::IsNullOrWhiteSpace([string]$values[$key])) {
            throw "Service Bus connection string is missing '$key'."
        }
    }
    return $values
}

function Get-ServiceBusSasToken {
    param(
        [Parameter(Mandatory)][string] $Audience,
        [Parameter(Mandatory)][string] $KeyName,
        [Parameter(Mandatory)][string] $Key,
        [ValidateRange(1, 60)][int] $ValidityMinutes = 10
    )

    $expires = [DateTimeOffset]::UtcNow.AddMinutes($ValidityMinutes).ToUnixTimeSeconds()
    $encodedAudience = [System.Uri]::EscapeDataString($Audience.ToLowerInvariant())
    $stringToSign = "$encodedAudience`n$expires"
    $hmac = [System.Security.Cryptography.HMACSHA256]::new([System.Text.Encoding]::UTF8.GetBytes($Key))
    try {
        $signatureBytes = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringToSign))
        $signature = [Convert]::ToBase64String($signatureBytes)
    }
    finally {
        $hmac.Dispose()
    }
    return "SharedAccessSignature sr=$encodedAudience&sig=$([System.Uri]::EscapeDataString($signature))&se=$expires&skn=$([System.Uri]::EscapeDataString($KeyName))"
}

$blobContainerUrlText = [string]$credentials.businessCentral.blobContainerUrl
$blobContainerUri = $null
$blobHostMatch = $null
if ((-not [Uri]::TryCreate($blobContainerUrlText, [UriKind]::Absolute, [ref]$blobContainerUri)) -or
    ($blobContainerUri.Scheme -cne 'https') -or
    ($blobContainerUri.UserInfo.Length -ne 0) -or
    ($blobContainerUri.Query.Length -ne 0) -or
    ($blobContainerUri.Fragment.Length -ne 0)) {
    throw 'The BC secret file contains an invalid public Azure Blob container URL.'
}
$blobHostMatch = [regex]::Match($blobContainerUri.Host, '^([a-z0-9]{3,24})\.blob\.core\.windows\.net\z')
if (-not $blobHostMatch.Success) {
    throw 'The BC secret file contains an invalid public Azure Blob host.'
}
$storageAccountName = $blobHostMatch.Groups[1].Value
$containerName = $blobContainerUri.AbsolutePath.Trim('/')
if (($containerName -notmatch '^[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])\z') -or $containerName.Contains('/')) {
    throw 'The BC secret file contains an invalid Blob container name.'
}
$bcWriteSas = ([string]$credentials.businessCentral.blobCreateWriteSasToken).TrimStart('?')
$jobsConnectionString = [string]$credentials.businessCentral.printJobsSendConnectionString
if ([string]::IsNullOrWhiteSpace($storageAccountName) -or
    [string]::IsNullOrWhiteSpace($containerName) -or
    ($bcWriteSas -notmatch '(^|&)sig=') -or
    [string]::IsNullOrWhiteSpace($jobsConnectionString)) {
    throw 'The secret file is missing the BC Blob-write or Service Bus send credential.'
}
$sasExpiry = [DateTimeOffset]::MinValue
if ((-not [DateTimeOffset]::TryParse(
        [string]$credentials.blobSasExpiresAtUtc,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal,
        [ref]$sasExpiry)) -or ($sasExpiry -le [DateTimeOffset]::UtcNow.AddMinutes(5))) {
    throw 'Blob SAS is expired or expires within five minutes. Run Initialize-Configuration.ps1 again.'
}

$previousStorageAccount = [Environment]::GetEnvironmentVariable('AZURE_STORAGE_ACCOUNT', 'Process')
$previousStorageSas = [Environment]::GetEnvironmentVariable('AZURE_STORAGE_SAS_TOKEN', 'Process')
try {
    [Environment]::SetEnvironmentVariable('AZURE_STORAGE_ACCOUNT', $storageAccountName, 'Process')
    [Environment]::SetEnvironmentVariable('AZURE_STORAGE_SAS_TOKEN', $bcWriteSas, 'Process')
    $contentType = switch ($Format) {
        'PDF' { 'application/pdf' }
        'ZPL' { 'text/plain' }
        default { 'application/octet-stream' }
    }
    [void] (Invoke-AzureCli -Arguments @(
        'storage', 'blob', 'upload',
        '--container-name', $containerName,
        '--name', $blobName,
        '--file', $FilePath,
        '--overwrite', 'true',
        '--validate-content',
        '--content-type', $contentType,
        '--metadata', "jobId=$jobIdText", "stationId=$StationId",
        '--auth-mode', 'key',
        '--output', 'none',
        '--only-show-errors'
    ))
}
finally {
    [Environment]::SetEnvironmentVariable('AZURE_STORAGE_ACCOUNT', $previousStorageAccount, 'Process')
    [Environment]::SetEnvironmentVariable('AZURE_STORAGE_SAS_TOKEN', $previousStorageSas, 'Process')
    $bcWriteSas = $null
}

$serviceBus = ConvertFrom-ServiceBusConnectionString -ConnectionString $jobsConnectionString
$endpointUri = [Uri]$serviceBus.Endpoint
$queueName = [string]$serviceBus.EntityPath
if (($endpointUri.Scheme -ne 'sb') -or
    ($endpointUri.UserInfo.Length -ne 0) -or
    ($endpointUri.Query.Length -ne 0) -or
    ($endpointUri.Fragment.Length -ne 0) -or
    ($endpointUri.AbsolutePath.Trim('/').Length -ne 0) -or
    (-not $endpointUri.Host.EndsWith('.servicebus.windows.net', [StringComparison]::OrdinalIgnoreCase))) {
    throw 'Service Bus endpoint must be a root sb://*.servicebus.windows.net URI.'
}
if (($queueName -cne 'print-jobs-queue') -or ([string]$serviceBus.SharedAccessKeyName -cne 'bc-send-jobs')) {
    throw "Smoke test requires the queue-scoped print-jobs-queue/bc-send-jobs credential; received '$queueName/$($serviceBus.SharedAccessKeyName)'."
}
$audience = "https://$($endpointUri.Host)/$queueName"
$sendUri = "$audience/messages"
$authorization = Get-ServiceBusSasToken -Audience $audience -KeyName ([string]$serviceBus.SharedAccessKeyName) -Key ([string]$serviceBus.SharedAccessKey)
$jobJson = $job | ConvertTo-Json -Depth 10 -Compress
$brokerProperties = [ordered]@{
    MessageId = $jobIdText
    CorrelationId = $jobIdText
    SessionId = $StationId
} | ConvertTo-Json -Compress

$httpClient = [System.Net.Http.HttpClient]::new()
$request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Post, $sendUri)
try {
    [void] $request.Headers.TryAddWithoutValidation('Authorization', $authorization)
    [void] $request.Headers.TryAddWithoutValidation('BrokerProperties', $brokerProperties)
    $request.Content = [System.Net.Http.StringContent]::new($jobJson, [System.Text.Encoding]::UTF8, 'application/json')
    $request.Content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::new('application/json')
    $response = $httpClient.SendAsync($request).GetAwaiter().GetResult()
    try {
        if (-not $response.IsSuccessStatusCode) {
            throw "Service Bus rejected the smoke-test job with HTTP $([int]$response.StatusCode) ($($response.ReasonPhrase)). The uploaded Blob remains for lifecycle cleanup."
        }
    }
    finally {
        $response.Dispose()
    }
}
finally {
    $request.Dispose()
    $httpClient.Dispose()
    $authorization = $null
    $jobsConnectionString = $null
    $serviceBus = $null
    $credentials = $null
}

Write-Host 'Smoke-test job uploaded and queued.' -ForegroundColor Green
Write-Host "JobId: $jobIdText"
Write-Host "StationId: $StationId"
Write-Host "PrinterId: $PrinterId"
Write-Host "Format/bytes: $Format / $($fileInfo.Length)"
Write-Host "BlobName: $blobName"
Write-Host 'Check the agent, physical printer, and printer-status-queue Active/DLQ counts. This raw Azure smoke creates no BC job row. No secret was printed.'
