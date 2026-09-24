[CmdletBinding()]
param(
    [ValidateSet('Test', 'Apply')]
    [string]$Action = 'Test',
    [string]$Module = '*'
)

$ErrorActionPreference = 'Stop'
$modules = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter "$Module.winget" -File | Sort-Object Name)
if (-not $modules.Count) {
    throw "No DSC module matches '$Module'."
}

$result = 0
foreach ($configuration in $modules) {
    Write-Host "$Action $($configuration.BaseName)"
    $arguments = @('configure')
    if ($Action -eq 'Test') { $arguments += 'test' }
    $arguments += @('--file', $configuration.FullName)

    & winget.exe @arguments
    if ($LASTEXITCODE -eq 1 -and $Action -eq 'Test') {
        $result = 1
    }
    elseif ($LASTEXITCODE -ne 0) {
        throw "$($configuration.Name) failed with WinGet exit code $LASTEXITCODE."
    }
}

exit $result
