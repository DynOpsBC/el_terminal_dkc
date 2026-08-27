[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
if (Test-Path -LiteralPath $runKey) {
    Remove-ItemProperty -Path $runKey -Name 'BCWMSPrintAgent' -ErrorAction SilentlyContinue
}
Write-Host 'Otomatik başlatma devre dışı bırakıldı.'
