[CmdletBinding()]
param(
    [string]$ExecutablePath = (Join-Path $env:LOCALAPPDATA 'Programs/BCWMS Print Agent/BCWMS.PrintAgent.exe')
)

$ErrorActionPreference = 'Stop'
$resolvedExe = (Resolve-Path -LiteralPath $ExecutablePath).Path
if (-not (Test-Path -LiteralPath $resolvedExe -PathType Leaf)) {
    throw "Agent executable bulunamadı: $ExecutablePath"
}

$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
New-Item -Path $runKey -Force | Out-Null
New-ItemProperty -Path $runKey -Name 'BCWMSPrintAgent' -PropertyType String -Value ('"{0}"' -f $resolvedExe) -Force | Out-Null
Write-Host 'Otomatik başlatma etkinleştirildi (mevcut Windows kullanıcısı).'
