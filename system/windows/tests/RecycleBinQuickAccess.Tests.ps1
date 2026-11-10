#requires -Version 7.0
# Shell interactions use in-memory fixtures; no Explorer pins are changed.
$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path (Split-Path $PSScriptRoot) 'scripts\RecycleBinQuickAccess.ps1'
$global:QuickAccessFixture = @{ Pinned=$false; Writes=0; Deny=$false; Drop=$false; Unavailable=$false }
function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Assert-Failure([scriptblock]$Action, [string]$Expected) {
    $message = ''
    try { & $Action } catch { $message = $_.Exception.Message }
    Assert ($message -like "*$Expected*") "Expected '$Expected'; got '$message'."
}
function New-Object {
    [CmdletBinding()]param([string]$ComObject)
    Assert ($ComObject -eq 'Shell.Application') 'Only Explorer may be accessed.'
    $shell = [pscustomobject]@{}
    $shell | Add-Member ScriptMethod Namespace {
        param($location)
        if ($global:QuickAccessFixture.Unavailable) { return $null }
        if ($location -eq 10) {
            $item = [pscustomobject]@{ Path='::{645FF040-5081-101B-9F08-00AA002F954E}' }
            $item | Add-Member ScriptMethod InvokeVerb {
                param($verb)
                Assert ($verb -eq 'pintohome') 'Only pinning Recycle Bin is permitted.'
                if ($global:QuickAccessFixture.Deny) { throw 'Shell access denied.' }
                $global:QuickAccessFixture.Writes++
                if (-not $global:QuickAccessFixture.Drop) { $global:QuickAccessFixture.Pinned=$true }
            }
            return [pscustomobject]@{ Self=$item }
        }
        Assert ($location -eq 'shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}') 'Only Quick access may be enumerated.'
        $folder = [pscustomobject]@{}
        $folder | Add-Member ScriptMethod Items {
            [pscustomobject]@{ Path='C:\Users\fixture\Documents' }
            $item = [pscustomobject]@{ Path='::{645FF040-5081-101B-9F08-00AA002F954E}' }
            $item | Add-Member ScriptMethod ExtendedProperty {
                param($name)
                Assert ($name -eq 'System.Home.IsPinned') 'Detection must check the pin state.'
                $global:QuickAccessFixture.Pinned
            }
            $item
        }
        $folder
    }
    $shell
}
function Start-Sleep { param([int]$Milliseconds) }
try {
    Assert (-not (& $scriptPath -Operation Get) -and -not (& $scriptPath -Operation Test)) 'An unpinned item must not pass detection.'
    Assert ($global:QuickAccessFixture.Writes -eq 0) 'Get and Test must be read-only.'
    & $scriptPath -Operation Set
    Assert (& $scriptPath -Operation Test) 'Recycle Bin must become pinned.'
    & $scriptPath -Operation Set
    Assert ($global:QuickAccessFixture.Writes -eq 1) 'Reapply must preserve the existing pin.'
    $global:QuickAccessFixture.Pinned=$false; $global:QuickAccessFixture.Deny=$true
    Assert-Failure { & $scriptPath -Operation Set } 'Shell access denied'
    $global:QuickAccessFixture.Deny=$false; $global:QuickAccessFixture.Drop=$true
    Assert-Failure { & $scriptPath -Operation Set } 'did not retain'
    $global:QuickAccessFixture.Unavailable=$true
    Assert-Failure { & $scriptPath -Operation Set } 'desktop session'
    Write-Output 'PASS: Recycle Bin pin detection, safe reapply, denied/ignored pins and unavailable Explorer'
} finally {
    Remove-Variable QuickAccessFixture -Scope Global
}
