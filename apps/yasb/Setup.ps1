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
if ($LASTEXITCODE -ne 0) {
    throw "The YASB checkout is incomplete. Inspect '$checkout', move it aside, then rerun apps\yasb\Setup.ps1 to clone again."
}
$changes = git.exe -C $checkout status --porcelain
if ($LASTEXITCODE -ne 0) { throw "Could not inspect '$checkout'. Resolve the Git error above and rerun setup." }
if ($changes) {
    throw "The YASB checkout has local changes. Preserve them before rerunning setup; keep customizations in '$PSScriptRoot\canopy'."
}
if ($revision -ne $pin.commit) {
    # Update only a clean vendor checkout. Pin the exact commit even if a tag moves.
    git.exe -C $checkout fetch --depth 1 origin $pin.commit
    if ($LASTEXITCODE -ne 0) { throw "Fetching pinned YASB commit $($pin.commit) failed. Rerun setup after resolving the Git error." }
    git.exe -C $checkout checkout --detach $pin.commit
    if ($LASTEXITCODE -ne 0) { throw "Selecting pinned YASB commit $($pin.commit) failed." }
}

$arguments = @('sync', '--frozen', '--project', $PSScriptRoot)
if (-not $Dev) { $arguments += '--no-dev' }
mise.exe exec -- uv @arguments
if ($LASTEXITCODE -ne 0) {
    throw 'Installing the Canopy runtime failed. Stop Canopy if its files are in use, resolve the uv error above, then rerun apps\yasb\Setup.ps1.'
}
