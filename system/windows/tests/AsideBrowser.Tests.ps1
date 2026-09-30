#requires -Version 7.0
# Run with pwsh -NoProfile -File .\system\windows\tests\AsideBrowser.Tests.ps1.
# Downloads, signatures, installation, and browser inventory are mocked.
$ErrorActionPreference = 'Stop'
$target = Join-Path (Split-Path $PSScriptRoot) 'scripts\AsideBrowser.ps1'

function Assert($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Reset-Fixture {
    $global:AsideBrowserTest = @{
        Installed = $false; Executable = $false; Downloads = 0; Launches = 0
        Signature = 'Valid'; Subject = 'CN=AT YOUR SIDE INC, O=AT YOUR SIDE INC'
        ExitCode = 0; NoInstall = $false; InstallerPath = $null
    }
}

function Test-Path {
    [CmdletBinding()]
    param([string]$LiteralPath, [string]$PathType)
    if ($LiteralPath -like 'HK*\Uninstall\Aside') { return $global:AsideBrowserTest.Installed }
    if ($LiteralPath -eq 'C:\AsideFixture\Aside.exe') { return $global:AsideBrowserTest.Executable }
    Microsoft.PowerShell.Management\Test-Path @PSBoundParameters
}

function Get-ItemProperty {
    param([string]$LiteralPath)
    @{ DisplayName = 'Aside'; InstallLocation = 'C:\AsideFixture'; DisplayVersion = '1.0' }
}

function Invoke-WebRequest {
    param([string]$Uri, [string]$OutFile)
    Assert ($Uri -eq 'https://aside.com/api/download/windows') 'Use the official Windows download endpoint.'
    $global:AsideBrowserTest.Downloads++
    $global:AsideBrowserTest.InstallerPath = $OutFile
    [IO.File]::WriteAllText($OutFile, 'fixture, not an executable')
}

function Get-AuthenticodeSignature {
    param([string]$LiteralPath)
    @{ Status = $global:AsideBrowserTest.Signature; SignerCertificate = @{ Subject = $global:AsideBrowserTest.Subject } }
}

function Start-Process {
    param([string]$FilePath, [string[]]$ArgumentList, [string]$WindowStyle, [switch]$Wait, [switch]$PassThru)
    Assert (($ArgumentList -join ' ') -eq '--silent --system') 'Use a silent system installation.'
    Assert ($WindowStyle -eq 'Hidden' -and $Wait -and $PassThru) 'Wait for the hidden installer and check its exit code.'
    $global:AsideBrowserTest.Launches++
    if (-not $global:AsideBrowserTest.NoInstall -and $global:AsideBrowserTest.ExitCode -eq 0) {
        $global:AsideBrowserTest.Installed = $true
        $global:AsideBrowserTest.Executable = $true
    }
    @{ ExitCode = $global:AsideBrowserTest.ExitCode }
}

function Assert-Failure([string]$Message) {
    $caught = $null
    try { & $target -Operation Set } catch { $caught = $_.Exception.Message }
    Assert ($caught -like "*$Message*") "Expected '$Message'; got '$caught'."
    Assert (-not (Test-Path -LiteralPath $global:AsideBrowserTest.InstallerPath)) 'Always remove the temporary installer.'
}

Reset-Fixture
Assert (-not (& $target -Operation Get).installed) 'Get must report a missing browser.'
Assert (-not (& $target -Operation Test)) 'Test must report a missing browser.'
Assert ($global:AsideBrowserTest.Downloads -eq 0) 'Read-only checks must not download or install.'
& $target -Operation Set
Assert (& $target -Operation Test) 'Verify both registration and executable after install.'
& $target -Operation Set
Assert ($global:AsideBrowserTest.Downloads -eq 1 -and $global:AsideBrowserTest.Launches -eq 1) 'Skip existing installations on reruns.'
Assert (-not (Test-Path -LiteralPath $global:AsideBrowserTest.InstallerPath)) 'Remove the temporary installer after success.'
$global:AsideBrowserTest.Executable = $false
Assert (-not (& $target -Operation Test)) 'A stale registry entry must not count as installed.'
Write-Output 'PASS: read-only detection, successful install, reruns, stale entries, and cleanup'

foreach ($case in @('UntrustedSignature', 'WrongPublisher')) {
    Reset-Fixture
    if ($case -eq 'UntrustedSignature') { $global:AsideBrowserTest.Signature = 'NotTrusted' }
    else { $global:AsideBrowserTest.Subject = 'CN=Someone Else, O=Someone Else' }
    Assert-Failure 'valid AT YOUR SIDE INC signature'
    Assert ($global:AsideBrowserTest.Launches -eq 0) 'Reject an untrusted download before execution.'
}
Write-Output 'PASS: untrusted signatures and unexpected publishers never execute'

Reset-Fixture
$global:AsideBrowserTest.ExitCode = 42
Assert-Failure 'exit code 42'
Reset-Fixture
$global:AsideBrowserTest.NoInstall = $true
Assert-Failure 'registered browser executable was not found'
Write-Output 'PASS: installer failures and false success are reported, with cleanup'
Remove-Variable -Name AsideBrowserTest -Scope Global
