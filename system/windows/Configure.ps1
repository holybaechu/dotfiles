#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet('Test', 'Apply')]
    [string]$Action = 'Test',
    [string]$Module = '*'
)

$ErrorActionPreference = 'Stop'
# Install replacements before removing apps when applying all modules.
$modules = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter "$Module.winget" -File |
    Sort-Object @{ Expression = { $_.BaseName -eq 'debloat' } }, Name)
if (-not $modules.Count) {
    throw "No DSC module matches '$Module'."
}
if ($Action -eq 'Apply' -and 'debloat' -in $modules.BaseName) {
    $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run debloating from a normal, non-administrator PowerShell window. WinGet will request elevation for Store apps; user-scope desktop apps cannot be removed from an elevated session.'
    }
}

$result = 0
foreach ($configuration in $modules) {
    Write-Host "$Action $($configuration.BaseName)"
    $arguments = @('configure')
    if ($Action -eq 'Test') { $arguments += 'test' }
    $arguments += @('--file', $configuration.FullName, '--accept-configuration-agreements', '--disable-interactivity')
    & winget.exe @arguments
    if ($LASTEXITCODE -eq 1 -and $Action -eq 'Test') {
        $result = 1
    }
    elseif ($LASTEXITCODE -ne 0) {
        throw "$($configuration.Name) failed with WinGet exit code $LASTEXITCODE."
    }
}

exit $result
