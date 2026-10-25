#requires -Version 5.1
# All machine operations and downloads use in-memory fixtures.
$ErrorActionPreference = 'Stop'
Import-Module Microsoft.PowerShell.Utility, Microsoft.PowerShell.Security
$target = Join-Path (Split-Path $PSScriptRoot) 'scripts\RemoveEdge.ps1'

function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Reset-Fixture {
    $global:EdgeFixture = @{
        Executable=$true; Registered=$true; Package=$true; Cached=$true
        BadHash=$false; BadSignature=$false; DownloadDenied=$false
        FalseSuccess=$false; AppxDenied=$false
        Calls=(New-Object 'System.Collections.Generic.List[string]')
    }
}
function Test-Path {
    [CmdletBinding()] param([string]$LiteralPath)
    if ($LiteralPath -like '*\Microsoft\Edge\Application\msedge.exe') { return $global:EdgeFixture.Executable }
    if ($LiteralPath -like 'HKLM:*\Uninstall\Microsoft Edge') { return $global:EdgeFixture.Registered }
    if ($LiteralPath -like '*\remove-edge\setup.exe') { return $global:EdgeFixture.Cached }
    throw "Unexpected path: $LiteralPath"
}
function Get-AppxPackage {
    [CmdletBinding()] param([switch]$AllUsers, [string]$Name)
    Assert ($AllUsers -and $Name -eq 'Microsoft.MicrosoftEdge.Stable') 'Query only the stable Edge browser for all users.'
    if ($global:EdgeFixture.Package) {
        [pscustomobject]@{ PackageFullName='Microsoft.MicrosoftEdge.Stable_mock'; NonRemovable=$false }
    }
}
function New-Item {
    [CmdletBinding()] param([string]$ItemType, [string]$Path, [switch]$Force)
    Assert ($ItemType -eq 'Directory' -and $Path -like '*\dotfiles\tools\remove-edge') 'Use the dedicated remover cache.'
}
function Invoke-WebRequest {
    [CmdletBinding()] param([switch]$UseBasicParsing, [string]$Uri, [string]$OutFile)
    $global:EdgeFixture.Calls.Add('download')
    Assert ($Uri -like '*/ad8d59b28d742e117be7585b534745ee40efb599/_Source/setup.x64.exe') 'Download the reviewed upstream revision.'
    if ($global:EdgeFixture.DownloadDenied) { throw 'Download denied.' }
    $global:EdgeFixture.Cached = $true
}
function Get-FileHash {
    [CmdletBinding()] param([string]$LiteralPath, [string]$Algorithm)
    [pscustomobject]@{ Hash=$(if ($global:EdgeFixture.BadHash) {'wrong'} else {'0950336e0d633eb645e0cf66780d2102a182caa184264d4f62146fe229f636e7'}) }
}
function Get-AuthenticodeSignature {
    [CmdletBinding()] param([string]$LiteralPath)
    [pscustomobject]@{ Status=$(if ($global:EdgeFixture.BadSignature) {'NotSigned'} else {'Valid'}) }
}
function Start-Process {
    [CmdletBinding()] param([string]$FilePath, [string[]]$ArgumentList, [string]$WindowStyle, [switch]$Wait, [switch]$PassThru)
    $global:EdgeFixture.Calls.Add('uninstall')
    Assert ($Wait -and '--system-level' -in $ArgumentList -and '--force-uninstall' -in $ArgumentList) 'Wait for the upstream browser-removal command.'
    Assert ('--msedgewebview' -notin $ArgumentList) 'Do not uninstall the shared WebView runtime.'
    if (-not $global:EdgeFixture.FalseSuccess) {
        $global:EdgeFixture.Executable=$false
        $global:EdgeFixture.Registered=$false
    }
    [pscustomobject]@{ ExitCode=19 }
}
function Remove-AppxPackage {
    [CmdletBinding()] param([string]$Package, [switch]$AllUsers)
    Assert ($AllUsers -and $Package -eq 'Microsoft.MicrosoftEdge.Stable_mock') 'Remove only the browser registration.'
    $global:EdgeFixture.Calls.Add('appx')
    if ($global:EdgeFixture.AppxDenied) { throw 'Appx removal denied.' }
    $global:EdgeFixture.Package=$false
}
function Assert-Failure([string]$Message) {
    $caught=$null
    try { & $target -Operation Set -WarningAction SilentlyContinue } catch { $caught=$_.Exception.Message }
    Assert ($caught -like "*$Message*") "Expected '$Message', got '$caught'."
}

Reset-Fixture
& $target -Operation Get | Out-Null
Assert (-not (& $target -Operation Test)) 'Detect an installed browser.'
Assert ($global:EdgeFixture.Calls.Count -eq 0) 'Get and Test must not download or uninstall.'
& $target -Operation Set -WarningAction SilentlyContinue
Assert (& $target -Operation Test) 'Verify both the browser and its registration are absent.'
$count=$global:EdgeFixture.Calls.Count
& $target -Operation Set
Assert ($global:EdgeFixture.Calls.Count -eq $count) 'An absent browser must not trigger a second removal.'
Write-Output 'PASS: read-only inventory, browser-only removal, verified success, and reruns'

foreach ($failure in @('BadHash','BadSignature','DownloadDenied')) {
    Reset-Fixture
    $global:EdgeFixture[$failure]=$true
    if ($failure -eq 'DownloadDenied') { $global:EdgeFixture.Cached=$false }
    $message = switch ($failure) { BadHash {'checksum'}; BadSignature {'signature'}; DownloadDenied {'Download denied'} }
    Assert-Failure $message
    Assert ('uninstall' -notin $global:EdgeFixture.Calls) 'Failed verification or download must prevent execution.'
}
Write-Output 'PASS: checksum, signature, and download failures prevent execution'

Reset-Fixture
$global:EdgeFixture.FalseSuccess=$true
Assert-Failure 'Edge remains installed'
Reset-Fixture
$global:EdgeFixture.AppxDenied=$true
Assert-Failure 'Appx removal denied'
Write-Output 'PASS: unsuccessful uninstalls and denied Appx removals remain failures'
