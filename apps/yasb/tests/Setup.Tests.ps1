#requires -Version 7.0
# Git and mise are mocked; no vendor checkout or Python environment is modified.
$ErrorActionPreference = 'Stop'
$runtime = Split-Path $PSScriptRoot
$target = Join-Path $runtime 'Setup.ps1'
$pin = Get-Content -LiteralPath (Join-Path $runtime 'upstream.json') -Raw | ConvertFrom-Json

function Assert($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Reset-Fixture {
    $global:CanopySetupTest = @{ Revision = $pin.commit; Dirty = $false; Fail = ''; Calls = @() }
}
function Test-Path {
    param([string]$LiteralPath)
    if ($LiteralPath -eq (Join-Path $runtime '.upstream')) { return $true }
    Microsoft.PowerShell.Management\Test-Path -LiteralPath $LiteralPath
}
function git.exe {
    $operation = $args[2]
    $global:CanopySetupTest.Calls += $operation
    $global:LASTEXITCODE = if ($operation -eq $global:CanopySetupTest.Fail) { 42 } else { 0 }
    if ($operation -eq 'rev-parse') { $global:CanopySetupTest.Revision }
    if ($operation -eq 'status' -and $global:CanopySetupTest.Dirty) { ' M src/main.py' }
    if ($operation -eq 'checkout') {
        Assert ($args[3] -eq '--detach' -and $args[4] -eq $pin.commit) 'Update only to the pinned commit.'
        if ($LASTEXITCODE -eq 0) { $global:CanopySetupTest.Revision = $pin.commit }
    }
}
function mise.exe {
    # PowerShell consumes the -- separator when calling a function fixture.
    Assert ($args[0] -eq 'exec' -and $args[1] -eq 'uv') 'Use mise-managed uv.'
    Assert ($args[2] -eq 'sync' -and '--frozen' -in $args) 'Keep dependency resolution frozen.'
    Assert ($global:CanopySetupTest.Revision -eq $pin.commit) 'Prepare pinned source before installing dependencies.'
    $global:CanopySetupTest.Calls += 'sync'
    $global:LASTEXITCODE = if ($global:CanopySetupTest.Fail -eq 'sync') { 42 } else { 0 }
}
function Assert-Failure([string]$Message) {
    $caught = ''
    try { & $target } catch { $caught = $_.Exception.Message }
    Assert ($caught -like "*$Message*") "Expected '$Message'; got '$caught'."
}

try {
    Reset-Fixture
    & $target
    Assert ('fetch' -notin $global:CanopySetupTest.Calls -and 'checkout' -notin $global:CanopySetupTest.Calls -and 'sync' -in $global:CanopySetupTest.Calls) 'Reuse matching source and install its dependencies.'
    Reset-Fixture
    $global:CanopySetupTest.Revision = 'old'
    & $target
    Assert ($global:CanopySetupTest.Revision -eq $pin.commit -and 'sync' -in $global:CanopySetupTest.Calls) 'Converge a clean checkout and install its dependencies.'
    Reset-Fixture
    $global:CanopySetupTest.Revision = 'old'
    $global:CanopySetupTest.Dirty = $true
    Assert-Failure 'local changes'
    Assert ('fetch' -notin $global:CanopySetupTest.Calls -and 'checkout' -notin $global:CanopySetupTest.Calls -and 'sync' -notin $global:CanopySetupTest.Calls) 'Never overwrite local vendor edits or install against unpinned source.'
    foreach ($case in @(@('rev-parse','incomplete'), @('status','Could not inspect'), @('fetch','Fetching'), @('sync','runtime failed'))) {
        Reset-Fixture
        $global:CanopySetupTest.Revision = 'old'
        $global:CanopySetupTest.Fail = $case[0]
        Assert-Failure $case[1]
        if ($case[0] -ne 'sync') { Assert ('sync' -notin $global:CanopySetupTest.Calls) 'A Git failure must stop dependency installation.' }
    }
    Write-Output 'PASS: pinned checkout, clean update, dirty preservation, Git failure, and mise-managed uv failure'
} finally { Remove-Variable CanopySetupTest -Scope Global }
