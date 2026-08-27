[CmdletBinding()]
param(
    [string]$Configuration = 'Release',
    [switch]$SkipTests,
    [string]$SigningScript = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'Paketleme için PowerShell 7 veya üzeri gereklidir.'
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$projectPath = Join-Path $projectRoot 'src/BCWMS.PrintAgent.Windows/BCWMS.PrintAgent.Windows.csproj'
$distRoot = Join-Path $projectRoot 'dist'
$packageRoot = Join-Path $distRoot 'BCWMS-Print-Agent-win-x64'
$appRoot = Join-Path $packageRoot 'app'
$installerRoot = Join-Path $packageRoot 'installer'
$zipPath = Join-Path $distRoot 'BCWMS-Print-Agent-win-x64.zip'

$dotnetVersion = (& dotnet --version).Trim()
if ([version]$dotnetVersion -lt [version]'10.0.100') {
    throw ".NET SDK 10.0.100 veya üzeri gerekli. Bulunan: $dotnetVersion"
}

if (-not $SkipTests) {
    & dotnet test (Join-Path $projectRoot 'BCWMS.PrintAgent.sln') -c $Configuration -p:EnableWindowsTargeting=true
    if ($LASTEXITCODE -ne 0) { throw 'Testler başarısız; paket üretilmedi.' }
}

if (Test-Path -LiteralPath $packageRoot) {
    Remove-Item -LiteralPath $packageRoot -Recurse -Force
}
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

New-Item -ItemType Directory -Path $appRoot -Force | Out-Null
New-Item -ItemType Directory -Path $installerRoot -Force | Out-Null

& dotnet publish $projectPath `
    -c $Configuration `
    -r win-x64 `
    --self-contained true `
    -p:EnableWindowsTargeting=true `
    -p:PublishSingleFile=false `
    -p:DebugType=None `
    -p:DebugSymbols=false `
    -o $appRoot
if ($LASTEXITCODE -ne 0) { throw 'win-x64 publish başarısız.' }

$requiredFiles = @(
    (Join-Path $appRoot 'BCWMS.PrintAgent.exe'),
    (Join-Path $appRoot 'BCWMS.PrintAgent.dll'),
    (Join-Path $appRoot 'Azure.Messaging.ServiceBus.dll'),
    (Join-Path $appRoot 'Azure.Storage.Blobs.dll'),
    (Join-Path $appRoot 'PdfiumViewer.dll'),
    (Join-Path $appRoot 'pdfium.dll')
)
foreach ($requiredFile in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Publish çıktısında zorunlu dosya yok: $requiredFile"
    }
}

Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'install.ps1') -Destination $installerRoot
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'uninstall.ps1') -Destination $installerRoot
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'enable-autostart.ps1') -Destination $installerRoot
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'disable-autostart.ps1') -Destination $installerRoot
Copy-Item -LiteralPath (Join-Path $projectRoot 'README.md') -Destination $packageRoot
Copy-Item -LiteralPath (Join-Path $projectRoot 'THIRD-PARTY-NOTICES.md') -Destination $packageRoot
Copy-Item -LiteralPath (Join-Path $projectRoot 'licenses') -Destination (Join-Path $packageRoot 'licenses') -Recurse

$authenticodeSigned = $false
if (-not [string]::IsNullOrWhiteSpace($SigningScript)) {
    if (-not $IsWindows) {
        throw 'Authenticode imzalama yalnız Windows yayın makinesinde desteklenir.'
    }

    $signingScriptPath = (Resolve-Path -LiteralPath $SigningScript).Path
    & $signingScriptPath -PackageRoot $packageRoot
    if (-not $?) {
        throw 'Pre-manifest signing script başarısız; paket üretilmedi.'
    }

    $signatureTargets = @(
        (Join-Path $appRoot 'BCWMS.PrintAgent.exe')
    ) + @(Get-ChildItem -LiteralPath $installerRoot -Filter '*.ps1' -File | Select-Object -ExpandProperty FullName)
    foreach ($signatureTarget in $signatureTargets) {
        $signature = Get-AuthenticodeSignature -LiteralPath $signatureTarget
        if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
            throw "Authenticode doğrulaması başarısız: $signatureTarget ($($signature.Status))"
        }
    }
    $authenticodeSigned = $true
}

$secretFiles = @(Get-ChildItem -LiteralPath $packageRoot -File -Recurse | Where-Object {
    $_.Name.EndsWith('.secrets.json', [StringComparison]::OrdinalIgnoreCase)
})
if ($secretFiles.Count -gt 0) {
    throw 'Paket plaintext *.secrets.json içeriyor; secret sızıntısını önlemek için paket üretilmedi.'
}

$textExtensions = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
@('.config', '.json', '.md', '.ps1', '.txt', '.xml') | ForEach-Object { [void]$textExtensions.Add($_) }
foreach ($textFile in Get-ChildItem -LiteralPath $packageRoot -File -Recurse | Where-Object { $textExtensions.Contains($_.Extension) }) {
    $content = Get-Content -LiteralPath $textFile.FullName -Raw
    if ($content -match 'SharedAccessKey=[A-Za-z0-9+/]{40,}={0,2}(?:;|$)' -or
        $content -match '(?:\?|&)sig=[A-Za-z0-9%_-]{20,}') {
        throw "Paket olası canlı connection string/SAS secret içeriyor; paket üretilmedi: $($textFile.Name)"
    }
}

$hashes = Get-ChildItem -LiteralPath $packageRoot -File -Recurse | Sort-Object FullName | ForEach-Object {
    $relative = [IO.Path]::GetRelativePath($packageRoot, $_.FullName).Replace('\', '/')
    [ordered]@{ path = $relative; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
}
[ordered]@{
    schemaVersion = 1
    productId = 'DynOps.BCWMS.PrintAgent'
    productVersion = '1.0.0'
    runtime = 'win-x64'
    selfContained = $true
    authenticodeSigned = $authenticodeSigned
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
    files = @($hashes)
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $packageRoot 'manifest.sha256.json') -Encoding utf8NoBOM

Compress-Archive -LiteralPath $packageRoot -DestinationPath $zipPath -CompressionLevel Optimal
Write-Host "Paket hazır: $zipPath"
