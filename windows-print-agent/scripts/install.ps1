[CmdletBinding()]
param(
    [string]$SourceDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'app'),
    [string]$InstallDirectory = (Join-Path $env:LOCALAPPDATA 'Programs/BCWMS Print Agent'),
    [switch]$DoNotStart
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$productId = 'DynOps.BCWMS.PrintAgent'
$markerName = '.bcwms-print-agent.install.json'

function Assert-SafeChildPath([string]$Parent, [string]$Child, [string]$Label) {
    $parentFull = [IO.Path]::GetFullPath($Parent).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $childFull = [IO.Path]::GetFullPath($Child)
    if (-not $childFull.StartsWith($parentFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label izin verilen dizinin dışında: $childFull"
    }
    return $childFull
}

function Get-PackageRelativePath([string]$Root, [string]$FullName) {
    return $FullName.Substring($Root.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
}

function Get-InstallRelativePath([string]$ManifestPath) {
    if ($ManifestPath.StartsWith('app/', [StringComparison]::Ordinal)) {
        return $ManifestPath.Substring(4)
    }
    return $ManifestPath
}

$source = (Resolve-Path -LiteralPath $SourceDirectory).Path
$packageRoot = (Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot)).Path
$expectedSource = [IO.Path]::GetFullPath((Join-Path $packageRoot 'app'))
if (-not [IO.Path]::GetFullPath($source).Equals($expectedSource, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Güvenlik nedeniyle SourceDirectory çıkarılan paketin app klasörü olmalıdır.'
}

$manifestPath = Join-Path $packageRoot 'manifest.sha256.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw 'Paket bütünlük manifesti bulunamadı: manifest.sha256.json'
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1 -or $manifest.productId -ne $productId -or
    -not $manifest.selfContained -or $manifest.runtime -ne 'win-x64') {
    throw 'Paket manifesti geçersiz veya beklenen win-x64 self-contained ürün değil.'
}

$expectedFiles = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($entry in @($manifest.files)) {
    $relative = [string]$entry.path
    if ([string]::IsNullOrWhiteSpace($relative) -or $relative.Contains('\') -or
        $relative.StartsWith('/') -or $relative.Contains('../') -or $relative.Contains(':')) {
        throw "Manifest güvensiz yol içeriyor: $relative"
    }
    if (-not $expectedFiles.Add($relative)) {
        throw "Manifest aynı yolu birden fazla içeriyor: $relative"
    }

    $candidate = Assert-SafeChildPath $packageRoot (Join-Path $packageRoot $relative.Replace('/', [IO.Path]::DirectorySeparatorChar)) 'Manifest yolu'
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Paket dosyası eksik: $relative"
    }
    $actualHash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne ([string]$entry.sha256).ToLowerInvariant()) {
        throw "Paket dosyası hash uyuşmazlığı: $relative"
    }
}

foreach ($file in Get-ChildItem -LiteralPath $packageRoot -File -Recurse) {
    if ($file.FullName.Equals($manifestPath, [StringComparison]::OrdinalIgnoreCase)) { continue }
    $relative = Get-PackageRelativePath $packageRoot $file.FullName
    if (-not $expectedFiles.Contains($relative)) {
        throw "Paket manifest dışı dosya içeriyor: $relative"
    }
}

if (-not $expectedFiles.Contains('app/BCWMS.PrintAgent.exe') -or
    -not $expectedFiles.Contains('app/pdfium.dll') -or
    -not $expectedFiles.Contains('installer/enable-autostart.ps1')) {
    throw 'Manifest zorunlu exe, güncel PDFium veya installer dosyalarını içermiyor.'
}

$running = Get-Process -Name 'BCWMS.PrintAgent' -ErrorAction SilentlyContinue
if ($running) {
    throw 'BCWMS Print Agent çalışıyor. Sistem tepsisi menüsünden Çıkış deyip kurulumu tekrar çalıştırın.'
}

$localPrograms = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs'))
$installFull = Assert-SafeChildPath $localPrograms $InstallDirectory 'Kurulum yolu'
$installParent = Split-Path -Parent $installFull
New-Item -ItemType Directory -Path $installParent -Force | Out-Null

if (Test-Path -LiteralPath $installFull) {
    $existingMarkerPath = Join-Path $installFull $markerName
    $existingExePath = Join-Path $installFull 'BCWMS.PrintAgent.exe'
    if (-not (Test-Path -LiteralPath $existingMarkerPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $existingExePath -PathType Leaf)) {
        throw "Var olan hedef geçerli BCWMS Print Agent kurulumu değil; otomatik üzerine yazılmadı: $installFull"
    }
    $existingMarker = Get-Content -LiteralPath $existingMarkerPath -Raw | ConvertFrom-Json
    if ($existingMarker.productId -ne $productId) {
        throw 'Var olan kurulum marker productId değeri uyuşmuyor.'
    }
}

$operationId = [Guid]::NewGuid().ToString('N')
$staging = Assert-SafeChildPath $installParent ($installFull + '.staging-' + $operationId) 'Staging yolu'
$backup = Assert-SafeChildPath $installParent ($installFull + '.backup-' + $operationId) 'Backup yolu'
$failed = Assert-SafeChildPath $installParent ($installFull + '.failed-' + $operationId) 'Failed yolu'
New-Item -ItemType Directory -Path $staging | Out-Null

try {
    foreach ($entry in @($manifest.files)) {
        $packageRelative = [string]$entry.path
        $installRelative = Get-InstallRelativePath $packageRelative
        $sourceFile = Join-Path $packageRoot $packageRelative.Replace('/', [IO.Path]::DirectorySeparatorChar)
        $destination = Assert-SafeChildPath $staging (Join-Path $staging $installRelative.Replace('/', [IO.Path]::DirectorySeparatorChar)) 'Staging dosyası'
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $sourceFile -Destination $destination
        $stagedHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($stagedHash -ne ([string]$entry.sha256).ToLowerInvariant()) {
            throw "Staging hash uyuşmazlığı: $installRelative"
        }
    }

    [ordered]@{
        schemaVersion = 1
        productId = $productId
        productVersion = [string]$manifest.productVersion
        manifestSha256 = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
        installedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $staging $markerName) -Encoding UTF8

    if (Test-Path -LiteralPath $installFull) {
        Move-Item -LiteralPath $installFull -Destination $backup
    }
    Move-Item -LiteralPath $staging -Destination $installFull

    foreach ($entry in @($manifest.files)) {
        $installRelative = Get-InstallRelativePath ([string]$entry.path)
        $installedFile = Assert-SafeChildPath $installFull (Join-Path $installFull $installRelative.Replace('/', [IO.Path]::DirectorySeparatorChar)) 'Kurulu dosya'
        if (-not (Test-Path -LiteralPath $installedFile -PathType Leaf) -or
            (Get-FileHash -LiteralPath $installedFile -Algorithm SHA256).Hash.ToLowerInvariant() -ne ([string]$entry.sha256).ToLowerInvariant()) {
            throw "Kurulum sonrası doğrulama başarısız: $installRelative"
        }
    }

}
catch {
    if (Test-Path -LiteralPath $installFull) {
        Move-Item -LiteralPath $installFull -Destination $failed -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $backup) {
        Move-Item -LiteralPath $backup -Destination $installFull
    }
    if (Test-Path -LiteralPath $failed) {
        Remove-Item -LiteralPath $failed -Recurse -Force -ErrorAction SilentlyContinue
    }
    throw
}
finally {
    if (Test-Path -LiteralPath $staging) {
        Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# The directory swap and external setup are now committed. Backup cleanup and
# process startup are deliberately outside the rollback boundary: a cleanup or
# launch error must never try to move a running new installation out from under
# Windows and strand the previous version in the backup directory.
if (Test-Path -LiteralPath $backup) {
    try {
        Remove-Item -LiteralPath $backup -Recurse -Force
    }
    catch {
        Write-Warning "Yeni kurulum doğrulandı ancak eski backup kaldırılamadı: $backup. Hata: $($_.Exception.Message)"
    }
}

# Shortcut and HKCU autostart are external to the atomically swapped install
# directory. Configure them only after the directory commit so a shell/registry
# failure cannot trigger a rollback that leaves stale external artifacts.
$installedExe = Join-Path $installFull 'BCWMS.PrintAgent.exe'
try {
    $startMenu = Join-Path $env:APPDATA 'Microsoft/Windows/Start Menu/Programs'
    $shortcutPath = Join-Path $startMenu 'BCWMS Print Agent.lnk'
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $installedExe
    $shortcut.WorkingDirectory = $installFull
    $shortcut.Description = 'BCWMS Cloud Print Agent'
    $shortcut.Save()

    & (Join-Path $installFull 'installer/enable-autostart.ps1') -ExecutablePath $installedExe
}
catch {
    Write-Warning "Agent kuruldu ancak Başlat menüsü/autostart ayarlanamadı; uygulamayı doğrudan açın. Hata: $($_.Exception.Message)"
}

if (-not $DoNotStart) {
    try {
        Start-Process -FilePath $installedExe -WorkingDirectory $installFull
    }
    catch {
        Write-Warning "Kurulum tamamlandı ancak agent otomatik başlatılamadı; Başlat menüsünden açın. Hata: $($_.Exception.Message)"
    }
}

Write-Host "BCWMS Print Agent atomik staging/rollback ile kuruldu: $installFull"
Write-Host 'Yönetim panelinden print-agent.runtime.secrets.json içe aktarın, yazıcıları seçin ve ayarları kaydedin.'
