#requires -Version 7.0
[CmdletBinding()]
param([ValidateSet('Get', 'Test', 'Set')][string]$Operation = 'Test')
$ErrorActionPreference = 'Stop'

function Get-ProtectionState {
    $status = Get-MpComputerStatus -ErrorAction Stop
    $preferences = Get-MpPreference -ErrorAction Stop
    $version = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
    $networkSupported = [int]$version.CurrentBuild -ge 22000 -and $version.EditionID -match '^(Professional|Enterprise|Education|IoTEnterprise)'
    [pscustomobject]@{
        Active = $status.AMRunningMode -eq 'Normal' -and $status.AntivirusEnabled
        PuaEnabled = [int]$preferences.PUAProtection -eq 1
        NetworkProtectionSupported = $networkSupported
        NetworkPrerequisitesMet = $status.RealTimeProtectionEnabled -and $status.BehaviorMonitorEnabled -and [int]$preferences.MAPSReporting -gt 0
        NetworkProtectionEnabled = [int]$preferences.EnableNetworkProtection -eq 1
    }
}
function Test-ProtectionState($State) {
    $State.Active -and $State.PuaEnabled -and (-not $State.NetworkProtectionSupported -or
        ($State.NetworkPrerequisitesMet -and $State.NetworkProtectionEnabled))
}
$state = Get-ProtectionState
if (-not $state.NetworkProtectionSupported) {
    Write-Warning 'Defender network protection requires a supported Windows Pro/Enterprise-family edition; PUA protection is configured separately.'
}
switch ($Operation) {
    Get { $state }
    Test { Test-ProtectionState $state }
    Set {
        if (-not $state.Active) { throw 'Microsoft Defender Antivirus must be active. This resource does not replace another antivirus or enable Defender forcibly.' }
        if (-not $state.PuaEnabled) { Set-MpPreference -PUAProtection Enabled -ErrorAction Stop }
        if ($state.NetworkProtectionSupported) {
            # Preserve the existing real-time, behavior-monitoring and cloud settings; report unmet prerequisites.
            if (-not $state.NetworkPrerequisitesMet) { throw 'Network protection requires real-time protection, behavior monitoring and cloud-delivered protection. Enable those prerequisites in Windows Security before applying this resource.' }
            if (-not $state.NetworkProtectionEnabled) { Set-MpPreference -EnableNetworkProtection Enabled -ErrorAction Stop }
        }
        if (-not (Test-ProtectionState (Get-ProtectionState))) {
            throw 'Defender did not retain the requested protections. Check managed policy/tamper protection in Windows Security; no protections were weakened.'
        }
    }
}
