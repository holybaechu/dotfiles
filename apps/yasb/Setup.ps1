#requires -Version 7.0

[CmdletBinding()]
param([switch]$Dev)

$ErrorActionPreference = 'Stop'
$pin = Get-Content (Join-Path $PSScriptRoot 'upstream.json') -Raw | ConvertFrom-Json
$checkout = Join-Path $PSScriptRoot '.upstream'

if (-not (Test-Path -LiteralPath $checkout)) {
    git.exe clone --depth 1 --branch $pin.tag $pin.url $checkout
    if ($LASTEXITCODE -ne 0) { throw 'Cloning YASB failed.' }
}

$revision = git.exe -C $checkout rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Could not read the YASB checkout.' }
if ($revision -ne $pin.commit) {
    throw "YASB must be at $($pin.commit). Inspect $checkout before updating it."
}
if (git.exe -C $checkout status --porcelain) {
    throw 'The YASB checkout has local changes. Keep customizations in canopy/.'
}

$arguments = @('sync', '--frozen', '--project', $PSScriptRoot)
if (-not $Dev) { $arguments += '--no-dev' }
uv.exe @arguments
if ($LASTEXITCODE -ne 0) { throw 'Installing the Canopy runtime failed.' }
