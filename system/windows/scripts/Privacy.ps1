#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Get', 'Test', 'Set', 'Restore')][string]$Operation = 'Test',
    [Parameter(Mandatory)][ValidateSet('User', 'Machine')][string]$Context
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\RegistryState.ps1"
$version = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
if ([int]$version.CurrentBuild -lt 22000) { throw 'This privacy configuration requires Windows 11.' }
$unsupported = @()

if ($Context -eq 'User') {
    $journalPath = Join-Path $env:LOCALAPPDATA 'dotfiles\rollback\privacy-user.json'
    $content = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    $explorer = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $rows = @(
        ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo', 'Enabled', 0)
        ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy', 'TailoredExperiencesWithDiagnosticDataEnabled', 0)
        ,@('HKCU:\Software\Policies\Microsoft\Windows\CloudContent', 'DisableTailoredExperiencesWithDiagnosticData', 1)
        ,@($explorer, 'Start_IrisRecommendations', 0)
        ,@($explorer, 'ShowSyncProviderNotifications', 0)
        ,@($explorer, 'TaskbarDa', 0)
        ,@($content, 'SubscribedContent-338388Enabled', 0)
        ,@($content, 'SubscribedContent-338389Enabled', 0)
        ,@($content, 'SubscribedContent-353694Enabled', 0)
        ,@($content, 'SubscribedContent-353696Enabled', 0)
        ,@($content, 'SubscribedContent-310093Enabled', 0)
        ,@($content, 'SystemPaneSuggestionsEnabled', 0)
        ,@($content, 'SoftLandingEnabled', 0)
        ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement', 'ScoobeSystemSettingEnabled', 0)
        ,@('HKCU:\Software\Microsoft\Siuf\Rules', 'NumberOfSIUFInPeriod', 0)
        ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR', 'AppCaptureEnabled', 0)
        ,@('HKCU:\System\GameConfigStore', 'GameDVR_Enabled', 0)
        ,@('HKCU:\Software\Microsoft\GameBar', 'UseNexusForGameBarEnabled', 0)
    )
    if ($version.EditionID -like 'Professional*') { $unsupported += 'The broad cloud consumer-content policy is not supported on Windows Pro. User suggestion settings are managed separately; Settings Home Microsoft 365 cards are not guaranteed to disappear.' }
} else {
    $journalPath = Join-Path $env:ProgramData 'dotfiles\rollback\privacy-machine.json'
    $rows = @(
        ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection', 'AllowTelemetry', 1)
        ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization', 'DODownloadMode', 0)
        ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR', 'AllowGameDVR', 0)
        ,@('HKLM:\SOFTWARE\Policies\Microsoft\Dsh', 'AllowNewsAndInterests', 0)
    )
    if ([int]$version.CurrentBuild -gt 26100 -or ([int]$version.CurrentBuild -eq 26100 -and [int]$version.UBR -ge 3915)) {
        $rows += ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI', 'DisableAIDataAnalysis', 1)
    } else { $unsupported += 'The Recall snapshot policy is unsupported on this Windows build; component inventory reports removal separately.' }
}
$settings = @($rows | ForEach-Object { @{ Path = $_[0]; Name = $_[1]; Value = $_[2]; Kind = 'DWord' } })
if ($Operation -ne 'Restore') { foreach ($message in $unsupported) { Write-Warning $message } }
switch ($Operation) {
    Get { @{ Settings = @($settings | ForEach-Object { @{ Path = $_.Path; Name = $_.Name; Matches = [bool](Test-RegistrySetting $_) } }); Unsupported = $unsupported } }
    Test { @($settings | Where-Object { -not (Test-RegistrySetting $_) }).Count -eq 0 }
    Set { foreach ($setting in $settings) { Set-TrackedRegistryValue $setting $journalPath } }
    Restore { Restore-RegistryValues $settings $journalPath }
}
