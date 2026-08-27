[CmdletBinding()]
param(
    [string]$InstallDirectory = (Join-Path $env:LOCALAPPDATA 'Programs/BCWMS Print Agent'),
    [switch]$ForceClose,
    [switch]$RemoveUserData
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$productId = 'DynOps.BCWMS.PrintAgent'
$fullInstallPath = [IO.Path]::GetFullPath($InstallDirectory)
$localPrograms = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs')).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $fullInstallPath.StartsWith($localPrograms, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Güvenlik nedeniyle yalnız LOCALAPPDATA\Programs altı kaldırılabilir: $fullInstallPath"
}

$markerPath = Join-Path $fullInstallPath '.bcwms-print-agent.install.json'
$installedExe = Join-Path $fullInstallPath 'BCWMS.PrintAgent.exe'
if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf) -or -not (Test-Path -LiteralPath $installedExe -PathType Leaf)) {
    throw 'Hedefte doğrulanmış BCWMS Print Agent product marker ve exe bulunamadı; recursive silme reddedildi.'
}
$marker = Get-Content -LiteralPath $markerPath -Raw | ConvertFrom-Json
if ($marker.schemaVersion -ne 1 -or $marker.productId -ne $productId) {
    throw 'Kurulum product marker geçersiz; recursive silme reddedildi.'
}

$running = Get-Process -Name 'BCWMS.PrintAgent' -ErrorAction SilentlyContinue | Where-Object {
    try { $_.Path -and [IO.Path]::GetFullPath($_.Path).Equals($installedExe, [StringComparison]::OrdinalIgnoreCase) } catch { $false }
}
if ($running -and -not $ForceClose) {
    throw 'Agent çalışıyor. Önce sistem tepsisi menüsünden Çıkış deyin veya açıkça -ForceClose kullanın.'
}
if ($running -and $ForceClose) {
    $running | Stop-Process -Force
}

& (Join-Path $fullInstallPath 'installer/disable-autostart.ps1')
$shortcutPath = Join-Path $env:APPDATA 'Microsoft/Windows/Start Menu/Programs/BCWMS Print Agent.lnk'
if (Test-Path -LiteralPath $shortcutPath) {
    Remove-Item -LiteralPath $shortcutPath -Force
}

Remove-Item -LiteralPath $fullInstallPath -Recurse -Force

if ($RemoveUserData) {
    $dataPath = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'DynOps/BCWMS Print Agent'))
    $expectedDataPath = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'DynOps/BCWMS Print Agent'))
    if (-not $dataPath.Equals($expectedDataPath, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'User-data yolu beklenen ürün yolu değil; silme reddedildi.'
    }
    if (Test-Path -LiteralPath $dataPath) {
        Remove-Item -LiteralPath $dataPath -Recurse -Force
        Write-Warning 'DPAPI ayarları, loglar, job journal ve status outbox kalıcı olarak kaldırıldı.'
    }
} else {
    Write-Host 'Kullanıcı verileri korundu. Tam kaldırma için -RemoveUserData kullanın.'
}

Write-Host 'BCWMS Print Agent kaldırıldı.'
