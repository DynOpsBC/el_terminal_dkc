Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-PowerShellVersion {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw 'PowerShell 7 or newer is required. Install it from https://aka.ms/powershell.'
    }
}

function Assert-AzureCli {
    if ($null -eq (Get-Command 'az' -CommandType Application -ErrorAction SilentlyContinue)) {
        throw 'Azure CLI (az) is required. Install it from https://aka.ms/installazurecli.'
    }
}

function Invoke-AzureCli {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]] $Arguments,

        [switch] $AllowFailure
    )

    $azCommand = Get-Command 'az' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $azCommand) {
        throw 'Azure CLI (az) is required. Install it from https://aka.ms/installazurecli.'
    }

    # The official Windows MSI/winget package exposes Azure CLI as az.cmd.
    # ProcessStartInfo with UseShellExecute=false cannot start a .cmd file
    # directly. Invoke that wrapper through PowerShell's native-command path
    # and use ACL-restricted temporary files so secret-bearing stdout is never
    # merged into errors or printed accidentally.
    if ($IsWindows -and ([System.IO.Path]::GetExtension($azCommand.Source) -in @('.cmd', '.bat'))) {
        $stdoutPath = [System.IO.Path]::GetTempFileName()
        $stderrPath = [System.IO.Path]::GetTempFileName()
        try {
            Protect-SecretFile -Path $stdoutPath
            Protect-SecretFile -Path $stderrPath

            & $azCommand.Source @Arguments 1> $stdoutPath 2> $stderrPath
            $exitCode = $LASTEXITCODE
            $stdout = [System.IO.File]::ReadAllText($stdoutPath).Trim()
            $stderr = [System.IO.File]::ReadAllText($stderrPath).Trim()

            if (($exitCode -ne 0) -and (-not $AllowFailure)) {
                if ([string]::IsNullOrWhiteSpace($stderr)) {
                    $stderr = 'No error detail was returned.'
                }
                throw "Azure CLI failed (exit $exitCode): $stderr"
            }

            return [pscustomobject]@{
                ExitCode = $exitCode
                StdOut = $stdout
                StdErr = $stderr
            }
        }
        finally {
            if (Test-Path -LiteralPath $stdoutPath) {
                Remove-Item -LiteralPath $stdoutPath -Force
            }
            if (Test-Path -LiteralPath $stderrPath) {
                Remove-Item -LiteralPath $stderrPath -Force
            }
        }
    }

    # Native executables are started by absolute path. ProcessStartInfo keeps
    # stdout (which can contain a secret) separate from stderr.
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $azCommand.Source
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    foreach ($argument in $Arguments) {
        [void] $startInfo.ArgumentList.Add($argument)
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw 'Azure CLI could not be started.'
    }

    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult().Trim()
    $stderr = $stderrTask.GetAwaiter().GetResult().Trim()

    if (($process.ExitCode -ne 0) -and (-not $AllowFailure)) {
        if ([string]::IsNullOrWhiteSpace($stderr)) {
            $stderr = 'No error detail was returned.'
        }
        throw "Azure CLI failed (exit $($process.ExitCode)): $stderr"
    }

    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        StdOut = $stdout
        StdErr = $stderr
    }
}

function Select-AzureSubscription {
    [CmdletBinding()]
    param(
        [string] $SubscriptionId
    )

    [void] (Invoke-AzureCli -Arguments @('account', 'show', '--only-show-errors', '--output', 'none'))

    if (-not [string]::IsNullOrWhiteSpace($SubscriptionId)) {
        [void] (Invoke-AzureCli -Arguments @('account', 'set', '--subscription', $SubscriptionId, '--only-show-errors'))
    }

    $accountResult = Invoke-AzureCli -Arguments @('account', 'show', '--query', '{id:id,name:name,tenantId:tenantId}', '--output', 'json', '--only-show-errors')
    return ($accountResult.StdOut | ConvertFrom-Json -Depth 5)
}

function Assert-ResourceGroupName {
    param([Parameter(Mandatory)][string] $Name)

    if (($Name.Length -gt 90) -or ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9._()\-]{0,89}\z') -or $Name.EndsWith('.')) {
        throw "Invalid resource-group name '$Name'. Use 1-90 letters, digits, '.', '_', '-', '(' or ')'; do not end with '.'."
    }
}

function Assert-NamePrefix {
    param([Parameter(Mandatory)][string] $Name)

    if ($Name -notmatch '^[a-z][a-z0-9-]{1,17}\z') {
        throw "Invalid name prefix '$Name'. Use 2-18 lowercase letters, digits or hyphens and start with a letter."
    }
}

function Assert-RoutingSegment {
    param(
        [Parameter(Mandatory)][string] $Value,
        [Parameter(Mandatory)][string] $Label
    )

    if ($Value -notmatch '^[A-Z0-9][A-Z0-9_\-]{0,31}\z') {
        throw "Invalid $Label '$Value'. Use 1-32 uppercase letters, digits, '_' or '-'."
    }
}

function Assert-StationId {
    param([Parameter(Mandatory)][string] $StationId)

    $segments = @($StationId.Split('.'))
    $invalidSegment = @($segments | Where-Object { $_ -notmatch '^[A-Z0-9][A-Z0-9_\-]{0,31}\z' })
    if (($StationId.Length -gt 128) -or ($segments.Count -ne 4) -or ($invalidSegment.Count -gt 0)) {
        throw "Invalid StationId '$StationId'. It must be exactly TENANT.COMPANY.WAREHOUSE.STATION; each segment uses 1-32 uppercase letters, digits, '_' or '-', total at most 128 characters."
    }
}

function Assert-AzureLocation {
    param([Parameter(Mandatory)][string] $Location)

    if ($Location -notmatch '^[a-z0-9]+\z') {
        throw "Invalid Azure location '$Location'. Use the canonical lowercase region name, for example 'westeurope' or 'northeurope'."
    }
    $locationResult = Invoke-AzureCli -Arguments @(
        'account', 'list-locations',
        '--query', "[?name=='$Location'].name | [0]",
        '--output', 'tsv',
        '--only-show-errors'
    )
    if ($locationResult.StdOut -ne $Location) {
        throw "Azure location '$Location' is not available in the selected subscription. Use 'az account list-locations -o table'."
    }
}

function Get-OptionalPropertyValue {
    param(
        $InputObject,
        [Parameter(Mandatory)][string] $Name
    )

    if ($null -eq $InputObject) {
        return $null
    }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Write-JsonFileAtomic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)] $Value,
        [ValidateRange(2, 100)][int] $Depth = 20
    )

    $directory = Split-Path -Parent $Path
    [void] [System.IO.Directory]::CreateDirectory($directory)
    $temporaryPath = Join-Path $directory ('.' + [System.IO.Path]::GetFileName($Path) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
    try {
        $json = $Value | ConvertTo-Json -Depth $Depth
        [System.IO.File]::WriteAllText($temporaryPath, $json + [Environment]::NewLine, $utf8WithoutBom)
        [System.IO.File]::Move($temporaryPath, $Path, $true)
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

function Write-SecretJsonFileAtomic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)] $Value,
        [ValidateRange(2, 100)][int] $Depth = 20
    )

    $directory = Split-Path -Parent $Path
    [void] [System.IO.Directory]::CreateDirectory($directory)
    $temporaryPath = Join-Path $directory ('.' + [System.IO.Path]::GetFileName($Path) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
    try {
        # Create an empty, exclusively held file and restrict its ACL before
        # any secret bytes are written. This avoids the write-then-chmod window
        # that can expose a SAS token on multi-user build machines.
        $emptyFile = [System.IO.File]::Open(
            $temporaryPath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None)
        $emptyFile.Dispose()
        Protect-SecretFile -Path $temporaryPath

        $json = $Value | ConvertTo-Json -Depth $Depth
        [System.IO.File]::WriteAllText($temporaryPath, $json + [Environment]::NewLine, $utf8WithoutBom)
        [System.IO.File]::Move($temporaryPath, $Path, $true)
        Protect-SecretFile -Path $Path
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

function Protect-SecretFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)

    if ($IsWindows) {
        $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $identitySid = $windowsIdentity.User
        if ($null -eq $identitySid) {
            throw "Current Windows user SID could not be resolved while protecting: $Path"
        }

        # Set-Acl can request SeSecurityPrivilege on folders that carry an
        # inherited SACL, even when only the DACL is intended to change.
        # icacls updates the DACL directly and is supported for a file owned by
        # the current non-administrator Windows user.
        $icaclsPath = Join-Path ([Environment]::GetFolderPath('System')) 'icacls.exe'
        if (-not (Test-Path -LiteralPath $icaclsPath -PathType Leaf)) {
            throw "Windows icacls.exe was not found while protecting: $Path"
        }
        $sidGrant = '*{0}:(F)' -f $identitySid.Value
        & $icaclsPath $Path '/inheritance:r' '/grant:r' $sidGrant '/c' '/q' *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "Windows could not restrict the secret file to the current user: $Path"
        }
        return
    }

    $chmod = Get-Command 'chmod' -ErrorAction SilentlyContinue
    if ($null -eq $chmod) {
        throw "Secret file was written but its permissions could not be restricted: $Path"
    }
    # Path is always normalized to an absolute path by the callers, so it
    # cannot be parsed as a chmod option on BSD/macOS implementations that do
    # not accept GNU's `--` separator.
    & $chmod.Source '600' $Path
    if ($LASTEXITCODE -ne 0) {
        throw "Secret file was written but chmod 600 failed: $Path"
    }
}

function Get-DeploymentOutputs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $ResourceGroupName,
        [Parameter(Mandatory)][string] $DeploymentName
    )

    $result = Invoke-AzureCli -Arguments @(
        'deployment', 'group', 'show',
        '--resource-group', $ResourceGroupName,
        '--name', $DeploymentName,
        '--query', 'properties.outputs',
        '--output', 'json',
        '--only-show-errors'
    )
    $raw = $result.StdOut | ConvertFrom-Json -Depth 20
    $outputs = [ordered]@{}
    foreach ($property in $raw.PSObject.Properties) {
        $outputs[$property.Name] = $property.Value.value
    }
    return $outputs
}
