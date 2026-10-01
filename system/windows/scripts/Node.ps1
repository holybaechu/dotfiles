#requires -Version 7.0

[CmdletBinding()]
param([ValidateSet('Get', 'Test', 'Set')][string]$Operation = 'Test')

$ErrorActionPreference = 'Stop'

# The nvm installer may have updated these after the DSC process started.
foreach ($name in 'NVM_HOME', 'NVM_SYMLINK') {
    $value = [Environment]::GetEnvironmentVariable($name, 'User')
    if (-not $value) { $value = [Environment]::GetEnvironmentVariable($name, 'Machine') }
    if (-not $value) { $value = [Environment]::GetEnvironmentVariable($name, 'Process') }
    [Environment]::SetEnvironmentVariable($name, $value, 'Process')
}

$state = @{ version = $null; npmInstalled = $false; managed = $false }
if ($env:NVM_SYMLINK -and (Test-Path -LiteralPath "$env:NVM_SYMLINK\node.exe")) {
    $state.version = ([string](& "$env:NVM_SYMLINK\node.exe" --version)).Trim()
    if ($LASTEXITCODE -ne 0) { $state.version = $null }
    $state.npmInstalled = Test-Path -LiteralPath "$env:NVM_SYMLINK\npm.cmd"
    $state.managed = (Get-Item -LiteralPath $env:NVM_SYMLINK).LinkType -eq 'SymbolicLink'
}
if ($Operation -eq 'Get') { $state; return }
if (-not $env:NVM_HOME -or -not (Test-Path -LiteralPath "$env:NVM_HOME\nvm.exe")) {
    if ($Operation -eq 'Test') { $false; return }
    throw 'Install nvm-windows before provisioning Node.js.'
}
if (-not $env:NVM_SYMLINK) { throw 'The nvm installer did not configure NVM_SYMLINK.' }

# Resolve LTS from Node's release index rather than pinning an aging major.
$release = (Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json') |
    Where-Object { $_.lts } | Select-Object -First 1
if (-not $release.version) { throw 'Could not resolve the latest Node.js LTS release.' }
if ($Operation -eq 'Test') {
    $state.managed -and $state.npmInstalled -and $state.version -eq $release.version
    return
}

$version = $release.version.TrimStart('v')
& "$env:NVM_HOME\nvm.exe" install $version
if ($LASTEXITCODE -ne 0) { throw "Installing Node.js $version with nvm failed." }
& "$env:NVM_HOME\nvm.exe" use $version
if ($LASTEXITCODE -ne 0) { throw "Activating Node.js $version with nvm failed." }
if ((Get-Item -LiteralPath $env:NVM_SYMLINK).LinkType -ne 'SymbolicLink') {
    throw 'NVM_SYMLINK must be managed by nvm. Remove a conflicting standalone Node.js installation first.'
}
if (([string](& "$env:NVM_SYMLINK\node.exe" --version)).Trim() -ne $release.version -or $LASTEXITCODE -ne 0) {
    throw 'The activated Node.js version does not match the requested LTS release.'
}
& "$env:NVM_SYMLINK\npm.cmd" --version
if ($LASTEXITCODE -ne 0) { throw 'Node.js installed, but npm verification failed.' }
