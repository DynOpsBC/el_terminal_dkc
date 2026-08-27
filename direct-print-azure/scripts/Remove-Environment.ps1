[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [string] $ResourceGroupName,

    [Parameter(Mandatory)]
    [string] $ConfirmResourceGroupName,

    [string] $SubscriptionId,

    [switch] $Wait
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')

Assert-PowerShellVersion
Assert-AzureCli
Assert-ResourceGroupName -Name $ResourceGroupName
[void] (Select-AzureSubscription -SubscriptionId $SubscriptionId)

if ($ConfirmResourceGroupName -cne $ResourceGroupName) {
    throw 'Teardown refused: -ConfirmResourceGroupName must exactly match -ResourceGroupName (case-sensitive).'
}

$groupResult = Invoke-AzureCli -Arguments @(
    'group', 'show',
    '--name', $ResourceGroupName,
    '--output', 'json',
    '--only-show-errors'
)
$group = $groupResult.StdOut | ConvertFrom-Json -Depth 10
$managedByTag = [string](Get-OptionalPropertyValue -InputObject $group.tags -Name 'managedBy')
$applicationTag = [string](Get-OptionalPropertyValue -InputObject $group.tags -Name 'application')
if (($managedByTag -ne 'direct-print-azure') -or ($applicationTag -ne 'bc-wms-direct-print')) {
    throw "Teardown refused: resource group '$ResourceGroupName' is not tagged as a dedicated direct-print-azure group."
}

if ($PSCmdlet.ShouldProcess("resource group $ResourceGroupName and every resource in it", 'Delete permanently')) {
    $arguments = @('group', 'delete', '--name', $ResourceGroupName, '--yes', '--only-show-errors')
    if (-not $Wait) {
        $arguments += '--no-wait'
    }
    [void] (Invoke-AzureCli -Arguments $arguments)
    if ($Wait) {
        Write-Host "Resource group deleted: $ResourceGroupName" -ForegroundColor Green
    }
    else {
        Write-Host "Resource-group deletion started: $ResourceGroupName"
    }
}
