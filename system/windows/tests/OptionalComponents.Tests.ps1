#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$target = Join-Path (Split-Path $PSScriptRoot) 'scripts\RemoveOptionalComponents.ps1'
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-components-test-' + [guid]::NewGuid().ToString('N'))
$savedProgramData = $env:ProgramData
$global:ComponentFixture = @{}
function Assert($Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Reset-Fixture {
    $global:ComponentFixture = @{ Features=@(); Capabilities=@(); Calls=@(); ProtectedAI=$true; PotPlayer=$true; Restart=$false; Noop=$false; PolicyExists=$false; PolicyValue=$null }
}
function Get-ItemProperty { param($Path) @{CurrentBuild='26200';UBR=9457} }
function Test-Path {
    [CmdletBinding()]param([string]$LiteralPath)
    if ($LiteralPath -like 'HKLM:*') { return $true }
    Microsoft.PowerShell.Management\Test-Path -LiteralPath $LiteralPath
}
function Get-Item {
    [CmdletBinding()]param($LiteralPath)
    $key = New-Object PSObject
    $key | Add-Member ScriptMethod GetValueNames { if ($global:ComponentFixture.PolicyExists) { 'AllowRecallEnablement' } }
    $key | Add-Member ScriptMethod GetValueKind { param($name) 'DWord' }
    $key | Add-Member ScriptMethod GetValue { param($name,$default,$options) $global:ComponentFixture.PolicyValue }
    $key
}
function New-ItemProperty {
    [CmdletBinding()]param($LiteralPath,$Name,$Value,$PropertyType,[switch]$Force)
    $global:ComponentFixture.PolicyExists=$true
    $global:ComponentFixture.PolicyValue=$Value
}
function Get-WindowsOptionalFeature { [CmdletBinding()]param([switch]$Online) $global:ComponentFixture.Features }
function Get-WindowsCapability { [CmdletBinding()]param([switch]$Online) $global:ComponentFixture.Capabilities }
function Get-AppxPackage { [CmdletBinding()]param([switch]$AllUsers,[string]$Name) if ($Name -eq 'MicrosoftWindows.Client.CoreAI' -and $global:ComponentFixture.ProtectedAI) { @{Name='MicrosoftWindows.Client.CoreAI';NonRemovable=$true} } }
function winget.exe { $global:LASTEXITCODE = if ($global:ComponentFixture.PotPlayer) { 0 } else { -1978335212 } }
function Remove-WindowsCapability {
    [CmdletBinding()]param([switch]$Online,[string]$Name,[switch]$NoRestart)
    Assert $NoRestart 'Never restart automatically.'
    $global:ComponentFixture.Calls += $Name
    if (-not $global:ComponentFixture.Noop) { ($global:ComponentFixture.Capabilities | Where-Object Name -eq $Name).State = 'NotPresent' }
    @{ RestartNeeded=$global:ComponentFixture.Restart }
}
function Disable-WindowsOptionalFeature {
    [CmdletBinding()]param([switch]$Online,[string]$FeatureName,[switch]$Remove,[switch]$NoRestart)
    Assert ($Remove -and $NoRestart) 'Remove payload through servicing, without an automatic restart.'
    $global:ComponentFixture.Calls += $FeatureName
    ($global:ComponentFixture.Features | Where-Object FeatureName -eq $FeatureName).State = if ($global:ComponentFixture.Restart) { 'DisablePending' } elseif ($global:ComponentFixture.Noop) { 'Disabled' } else { 'DisabledWithPayloadRemoved' }
    @{ RestartNeeded=$global:ComponentFixture.Restart }
}
try {
    $env:ProgramData = $scratch
    Reset-Fixture
    $global:ComponentFixture.Features = @(
        [pscustomobject]@{FeatureName='Recall';State='Enabled'}
        [pscustomobject]@{FeatureName='VirtualMachinePlatform';State='Enabled'}
    )
    $global:ComponentFixture.Capabilities = @(
        [pscustomobject]@{Name='Language.Handwriting~~~ko-KR~0.0.1.0';State='Installed'}
        [pscustomobject]@{Name='Language.Basic~~~ko-KR~0.0.1.0';State='Installed'}
        [pscustomobject]@{Name='Print.Fax.Scan~~~~0.0.1.0';State='Installed'}
        [pscustomobject]@{Name='Print.Management.Console~~~~0.0.1.0';State='Installed'}
    )
    $state = & $target -Operation Get -WarningAction SilentlyContinue
    Assert ($state.Unsupported.Count -eq 1) 'Protected Click to Do must remain visibly unsupported.'
    Assert ($global:ComponentFixture.Calls.Count -eq 0) 'Get must not remove anything.'
    & $target -Operation Set -WarningAction SilentlyContinue
    Assert ($global:ComponentFixture.Calls.Count -eq 3) 'Only selected components may be removed.'
    Assert ($global:ComponentFixture.Features[1].State -eq 'Enabled' -and $global:ComponentFixture.Capabilities[1].State -eq 'Installed' -and $global:ComponentFixture.Capabilities[3].State -eq 'Installed') 'Preserve virtualization, language basics, and print management.'
    & $target -Operation Set -WarningAction SilentlyContinue
    Assert ($global:ComponentFixture.Calls.Count -eq 3) 'Reruns must not remove already-absent components.'
    Write-Output 'PASS: exact component selection, preserved dependencies, unsupported AI reporting, and reruns'

    Reset-Fixture
    $global:ComponentFixture.Features = @([pscustomobject]@{FeatureName='WindowsMediaPlayer';State='Enabled'})
    $global:ComponentFixture.PotPlayer = $false
    $caught = $false
    try { & $target -Operation Set -WarningAction SilentlyContinue } catch { $caught = $_.Exception.Message -like '*PotPlayer*' }
    Assert ($caught -and $global:ComponentFixture.Calls.Count -eq 0) 'Require the replacement before legacy player removal.'

    Reset-Fixture
    $global:ComponentFixture.Features = @([pscustomobject]@{FeatureName='Recall';State='Enabled'})
    $global:ComponentFixture.Restart = $true
    & $target -Operation Set -WarningAction SilentlyContinue
    Assert (-not (& $target -Operation Test -WarningAction SilentlyContinue)) 'Pending restart must not count as removal.'
    $global:ComponentFixture.Restart = $false
    $global:ComponentFixture.Noop = $true
    $global:ComponentFixture.Features[0].State = 'Enabled'
    & $target -Operation Set -WarningAction SilentlyContinue
    $state = & $target -Operation Get -WarningAction SilentlyContinue
    Assert (@($state.Unsupported | Where-Object { $_ -like '*not counted as removed*' }).Count -eq 1) 'A disabled-only feature must remain visibly incomplete.'
    Assert ($global:ComponentFixture.PolicyValue -eq 0) 'Apply the supported Recall removal policy after recording the original state.'
    Write-Output 'PASS: player prerequisite, pending restart, Recall policy, and disabled-only reporting'
} finally {
    $env:ProgramData = $savedProgramData
    $resolved = [IO.Path]::GetFullPath($scratch)
    if (-not $resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'dotfiles-components-test-*') { throw 'Unsafe fixture cleanup path.' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
    Remove-Variable ComponentFixture -Scope Global
}
