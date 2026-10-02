#requires -Version 7.0
# All registry, service, native preference and Defender commands use in-memory fixtures.
$ErrorActionPreference = 'Stop'
$scripts = Join-Path (Split-Path $PSScriptRoot) 'scripts'
$global:SelectedFixture = @{
    Registry=@{}; Writes=0; Deny=''; Drop=''; Edition='Professional'; Build='26200'; UBR=9457
    ServiceStart='Automatic'; ServiceStatus='Running'; ServiceWrites=0
    Active=$true; RealTime=$true; Behavior=$true; Cloud=2; Pua=0; Network=0; DefenderWrites=0; DropDefender=$false
}
function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
if ('Dotfiles.SelectedPreferences' -as [type]) { throw 'Run this fixture in a fresh PowerShell process.' }
Add-Type -Namespace Dotfiles -Name SelectedPreferences -MemberDefinition @'
public static bool Arranging = true;
public static uint Flags = 69;
public static int Writes = 0;
public static bool Deny = false;
public static bool WindowArrangingEnabled() { return Arranging; }
public static void DisableWindowArranging() {
    if (Deny) throw new System.InvalidOperationException("Native preference denied.");
    Writes++; Arranging = false;
}
public static uint StickyFlags() { return Flags; }
public static void DisableStickyShortcut() {
    if (Deny) throw new System.InvalidOperationException("Native preference denied.");
    Writes++; Flags &= ~4u;
}
public static void Notify() { }
'@
Add-Type -Namespace Dotfiles -Name AccentColor -MemberDefinition @'
public static int Notifications = 0;
public static void Notify() { Notifications++; }
'@
function Test-Path {
    [CmdletBinding()]param([string]$LiteralPath)
    Assert ($LiteralPath -match '^HK(CU|LM):') 'Only registry paths may be inspected by this fixture.'
    $global:SelectedFixture.Registry.ContainsKey($LiteralPath)
}
function Get-Item {
    [CmdletBinding()]param([string]$LiteralPath)
    $item = [pscustomobject]@{ Data=$global:SelectedFixture.Registry[$LiteralPath] }
    $item | Add-Member ScriptMethod GetValueNames { @($this.Data.Keys) }
    $item | Add-Member ScriptMethod GetValueKind { param($name) $this.Data[$name].Kind }
    $item | Add-Member ScriptMethod GetValue { param($name,$default,$options) $this.Data[$name].Value }
    $item
}
function Get-ItemProperty {
    [CmdletBinding()]param([string]$Path)
    @{ CurrentBuild=$global:SelectedFixture.Build; UBR=$global:SelectedFixture.UBR; EditionID=$global:SelectedFixture.Edition }
}
function New-Item {
    [CmdletBinding()]param([string]$Path,[switch]$Force)
    Assert ($Path -match '^HK(CU|LM):') 'New preference groups must not create backups or filesystem paths.'
    $global:SelectedFixture.Registry[$Path] = @{}
}
function New-ItemProperty {
    [CmdletBinding()]param([string]$LiteralPath,[string]$Name,$Value,[string]$PropertyType,[switch]$Force)
    if ($Name -eq $global:SelectedFixture.Deny) { throw 'Registry access denied.' }
    $global:SelectedFixture.Writes++
    if ($Name -ne $global:SelectedFixture.Drop) { $global:SelectedFixture.Registry[$LiteralPath][$Name] = @{Value=$Value;Kind=$PropertyType} }
}
function Get-Service {
    [CmdletBinding()]param([string]$Name)
    Assert ($Name -eq 'DiagTrack') 'Only the selected telemetry service may be managed.'
    @{ StartType=$global:SelectedFixture.ServiceStart; Status=$global:SelectedFixture.ServiceStatus }
}
function Set-Service {
    [CmdletBinding()]param([string]$Name,[string]$StartupType)
    Assert ($Name -eq 'DiagTrack' -and $StartupType -eq 'Disabled') 'Unexpected service change.'
    $global:SelectedFixture.ServiceStart = $StartupType
    $global:SelectedFixture.ServiceWrites++
}
function Stop-Service {
    [CmdletBinding()]param([string]$Name)
    Assert ($Name -eq 'DiagTrack') 'Unexpected service stop.'
    $global:SelectedFixture.ServiceStatus = 'Stopped'
    $global:SelectedFixture.ServiceWrites++
}
function Get-MpComputerStatus {
    [CmdletBinding()]param()
    @{ AMRunningMode=$(if($global:SelectedFixture.Active){'Normal'}else{'Passive'}); AntivirusEnabled=$global:SelectedFixture.Active
        RealTimeProtectionEnabled=$global:SelectedFixture.RealTime; BehaviorMonitorEnabled=$global:SelectedFixture.Behavior }
}
function Get-MpPreference {
    [CmdletBinding()]param()
    @{ PUAProtection=$global:SelectedFixture.Pua; EnableNetworkProtection=$global:SelectedFixture.Network; MAPSReporting=$global:SelectedFixture.Cloud }
}
function Set-MpPreference {
    [CmdletBinding()]param([string]$PUAProtection,[string]$EnableNetworkProtection)
    $global:SelectedFixture.DefenderWrites++
    if ($PUAProtection) { Assert ($PUAProtection -eq 'Enabled') 'PUA protection must only be enabled.'; $global:SelectedFixture.Pua=1 }
    if ($EnableNetworkProtection) {
        Assert ($EnableNetworkProtection -eq 'Enabled') 'Network protection must only be enabled.'
        if (-not $global:SelectedFixture.DropDefender) { $global:SelectedFixture.Network=1 }
    }
}
function Assert-Failure([scriptblock]$Action, [string]$Expected) {
    $message = ''
    try { & $Action } catch { $message=$_.Exception.Message }
    Assert ($message -like "*$Expected*") "Expected '$Expected'; got '$message'."
}
try {
    $selected = Join-Path $scripts 'SelectedPreferences.ps1'
    $defender = Join-Path $scripts 'DefenderProtection.ps1'
    $advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $global:SelectedFixture.Registry[$advanced] = @{ ShowRecent=@{Kind='DWord';Value=1}; TaskbarEndTask=@{Kind='DWord';Value=0} }
    $state = & $selected -Operation Get -Context User
    Assert ($global:SelectedFixture.Writes -eq 0 -and [Dotfiles.SelectedPreferences]::Writes -eq 0) 'Get must be read-only.'
    Assert (@($state.Settings | Where-Object Path -like 'HKCU:\Software\Policies\*').Count -eq 0) 'Normal-user changes must not require protected policy keys.'
    & $selected -Operation Set -Context User
    Assert (& $selected -Operation Test -Context User) 'User preferences must converge.'
    Assert ($global:SelectedFixture.Registry[$advanced].ShowRecent.Value -eq 1 -and $global:SelectedFixture.Registry[$advanced].TaskbarEndTask.Value -eq 0) 'Declined and unrelated preferences must survive.'
    $writes=$global:SelectedFixture.Writes; $nativeWrites=[Dotfiles.SelectedPreferences]::Writes
    & $selected -Operation Set -Context User
    Assert ($global:SelectedFixture.Writes -eq $writes -and [Dotfiles.SelectedPreferences]::Writes -eq $nativeWrites) 'Reapply must avoid registry/native writes.'
    $global:SelectedFixture.Registry[$advanced].LaunchTo.Value=0
    $global:SelectedFixture.Deny='LaunchTo'
    Assert-Failure { & $selected -Operation Set -Context User } 'Registry access denied'
    $global:SelectedFixture.Deny=''
    [Dotfiles.SelectedPreferences]::Arranging=$true; [Dotfiles.SelectedPreferences]::Deny=$true
    Assert-Failure { & $selected -Operation Set -Context User } 'Native preference denied'
    [Dotfiles.SelectedPreferences]::Deny=$false
    & $selected -Operation Set -Context UserPolicy
    Assert (& $selected -Operation Test -Context UserPolicy) 'Elevated user policy must be independently checkable.'
    & $selected -Operation Set -Context Machine -WarningAction SilentlyContinue
    Assert (& $selected -Operation Test -Context Machine -WarningAction SilentlyContinue) 'Machine preferences and DiagTrack must converge.'
    $serviceWrites=$global:SelectedFixture.ServiceWrites
    & $selected -Operation Set -Context Machine -WarningAction SilentlyContinue
    Assert ($global:SelectedFixture.ServiceWrites -eq $serviceWrites) 'Already stopped/disabled services must be skipped.'
    $fileSystem='HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
    $global:SelectedFixture.Registry[$fileSystem].LongPathsEnabled.Value=0; $global:SelectedFixture.Drop='LongPathsEnabled'
    Assert-Failure { & $selected -Operation Set -Context Machine -WarningAction SilentlyContinue } 'did not retain'
    $global:SelectedFixture.Drop=''
    $global:SelectedFixture.Build='26100'; $global:SelectedFixture.UBR=1
    $state=& $selected -Operation Get -Context Machine -WarningAction SilentlyContinue
    Assert ($state.Unsupported.Count -gt 0 -and @($state.Settings | Where-Object Path -like '*Policies\Paint').Count -eq 0) 'Unsupported Paint policies must be reported and excluded.'
    $global:SelectedFixture.Build='26200'; $global:SelectedFixture.UBR=9457
    Write-Output 'PASS: selected preference scope, convergence, denied/ignored changes and unsupported builds'

    $accentScript = Join-Path $scripts 'AccentColor.ps1'
    $accentPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
    $writes = $global:SelectedFixture.Writes
    $state = & $accentScript -Operation Get
    Assert ($global:SelectedFixture.Writes -eq $writes -and -not (& $accentScript -Operation Test)) 'Reading an unset accent must not change Windows.'
    & $accentScript -Operation Set
    Assert (& $accentScript -Operation Test) 'Accent colors and the binary palette must converge.'
    Assert ($global:SelectedFixture.Registry[$accentPath].AccentColorMenu.Value -eq 0xff3dab7c) 'Accent must encode the bright wallpaper green as ABGR.'
    $writes = $global:SelectedFixture.Writes
    & $accentScript -Operation Set
    Assert ($global:SelectedFixture.Writes -eq $writes -and [Dotfiles.AccentColor]::Notifications -eq 1) 'Matching accents must not write or broadcast again.'
    $global:SelectedFixture.Registry[$accentPath].AccentPalette.Value[8] = 0
    Assert (-not (& $accentScript -Operation Test)) 'A partially matching binary palette must fail verification.'
    $global:SelectedFixture.Deny = 'AccentPalette'
    Assert-Failure { & $accentScript -Operation Set } 'Registry access denied'
    $global:SelectedFixture.Deny = ''; $global:SelectedFixture.Drop = 'AccentPalette'
    Assert-Failure { & $accentScript -Operation Set } 'did not retain'
    $global:SelectedFixture.Drop = ''
    & $accentScript -Operation Set
    Write-Output 'PASS: accent encoding, binary palette verification, convergence and denied/ignored writes'

    & $defender -Operation Set
    Assert (& $defender -Operation Test) 'Defender protections must converge.'
    $writes=$global:SelectedFixture.DefenderWrites
    & $defender -Operation Set
    Assert ($global:SelectedFixture.DefenderWrites -eq $writes) 'Defender reapply must skip matching preferences.'
    $global:SelectedFixture.Network=0; $global:SelectedFixture.DropDefender=$true
    Assert-Failure { & $defender -Operation Set } 'did not retain'
    $global:SelectedFixture.DropDefender=$false; $global:SelectedFixture.Cloud=0
    Assert-Failure { & $defender -Operation Set } 'requires real-time protection'
    Assert ($global:SelectedFixture.Cloud -eq 0 -and $global:SelectedFixture.RealTime -and $global:SelectedFixture.Behavior) 'Unselected Defender prerequisites must not be changed.'
    $global:SelectedFixture.Active=$false
    Assert-Failure { & $defender -Operation Set } 'must be active'
    $global:SelectedFixture.Active=$true; $global:SelectedFixture.Edition='Core'
    & $defender -Operation Set -WarningAction SilentlyContinue
    Assert ((& $defender -Operation Get -WarningAction SilentlyContinue).NetworkProtectionSupported -eq $false) 'Unsupported network protection must be reported.'
    Write-Output 'PASS: active Defender, prerequisites, unsupported editions and policy/tamper rejection'
} finally { Remove-Variable SelectedFixture -Scope Global }
