#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet('Test', 'Apply')]
    [string]$Action = 'Test',
    [string[]]$Module = '*'
)

$ErrorActionPreference = 'Stop'
# Keep bootstrap and explicit configuration runs in the same order.
# Install replacements before removing apps; preserve each resource's privileges.
$moduleOrder = @('packages', 'preferences', 'startup', 'privacy', 'graphics', 'debloat')
$modules = @(foreach ($pattern in $Module) {
    $matches = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter "$pattern.winget" -File)
    if (-not $matches.Count) { throw "No DSC module matches '$pattern'." }
    $matches
})
$modules = @($modules | Sort-Object FullName -Unique | Sort-Object @{
    Expression = {
        $index = [Array]::IndexOf($moduleOrder, $_.BaseName)
        if ($index -lt 0) { $moduleOrder.Count } else { $index }
    }
}, Name)
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
