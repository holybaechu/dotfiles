#requires -Version 7.0

[CmdletBinding()]
param([ValidateSet('Get', 'Test', 'Set')][string]$Operation = 'Test')

$ErrorActionPreference = 'Stop'

# Pick up WinGet's newly installed mise executable in this DSC worker.
$paths = @($env:PATH, [Environment]::GetEnvironmentVariable('PATH', 'Machine'),
    [Environment]::GetEnvironmentVariable('PATH', 'User'))
$env:PATH = ([Environment]::ExpandEnvironmentVariables($paths -join ';').Split(';') |
    Where-Object { $_ } | Select-Object -Unique) -join ';'
$mise = Get-Command mise.exe -CommandType Application -ErrorAction SilentlyContinue
$state = @{ bunInstalled = $false; nodeInstalled = $false }
if ($mise) {
    $json = & $mise.Source ls --global --installed --json
    if ($LASTEXITCODE -ne 0) { throw 'Reading mise runtime state failed.' }
    $tools = ($json -join "`n") | ConvertFrom-Json
    $state.bunInstalled = @($tools.bun | Where-Object { $_.requested_version -eq 'latest' }).Count -gt 0
    $state.nodeInstalled = @($tools.node | Where-Object { $_.requested_version -eq 'lts' }).Count -gt 0
}
if ($Operation -eq 'Get') { $state; return }
if ($Operation -eq 'Test') { $state.bunInstalled -and $state.nodeInstalled; return }
if (-not $mise) { throw 'Install mise before provisioning JavaScript runtimes.' }

& $mise.Source use --global bun@latest node@lts
if ($LASTEXITCODE -ne 0) { throw 'Installing Bun and Node LTS through mise failed.' }
foreach ($command in 'bun', 'node', 'npm.cmd') {
    & $mise.Source exec bun@latest node@lts -- $command --version
    if ($LASTEXITCODE -ne 0) { throw "Verifying mise's $command failed." }
}
