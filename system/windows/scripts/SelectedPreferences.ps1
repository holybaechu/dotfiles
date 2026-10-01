#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Get', 'Test', 'Set')][string]$Operation = 'Test',
    [Parameter(Mandatory)][ValidateSet('User', 'UserPolicy', 'Machine')][string]$Context
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\RegistryState.ps1"
$version = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
$build = [int]$version.CurrentBuild
if ($build -lt 22000) { throw 'These selected preferences require Windows 11.' }
$unsupported = @()

if ($Context -eq 'User') {
    $advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $content = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    $rows = @(
        ,@($advanced, 'LaunchTo', 1)
        ,@('HKCU:\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}', 'System.IsPinnedToNameSpaceTree', 0)
        ,@('HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}', 'System.IsPinnedToNameSpaceTree', 0)
        ,@($advanced, 'MultiTaskingAltTabFilter', 3)
        ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize', 'AppsUseLightTheme', 0)
        ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize', 'SystemUsesLightTheme', 0)
        ,@($advanced, 'SnapAssist', 0)
        ,@($advanced, 'EnableSnapBar', 0)
        ,@($advanced, 'EnableSnapAssistFlyout', 0)
        ,@($advanced, 'ShowTaskViewButton', 0)
        ,@($advanced, 'TaskbarMn', 0)
        ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\Search', 'SearchboxTaskbarMode', 0)
        ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\Search', 'BingSearchEnabled', 0)
        ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings', 'IsDynamicSearchBoxEnabled', 0)
        ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings', 'IsMSACloudSearchEnabled', 0)
        ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings', 'IsAADCloudSearchEnabled', 0)
        ,@($content, 'SilentInstalledAppsEnabled', 0)
        ,@($content, 'SubscribedContent-338393Enabled', 0)
        ,@($content, 'SubscribedContent-353698Enabled', 0)
        ,@($advanced, 'Start_AccountNotifications', 0)
        ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications', 'EnableAccountNotifications', 0)
        ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.Suggested', 'Enabled', 0)
        ,@('HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy', 'HasAccepted', 0)
        ,@('HKCU:\Software\Microsoft\Input\TIPC', 'Enabled', 0)
        ,@('HKCU:\Software\Microsoft\InputPersonalization', 'RestrictImplicitInkCollection', 1)
        ,@('HKCU:\Software\Microsoft\InputPersonalization', 'RestrictImplicitTextCollection', 1)
        ,@('HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore', 'HarvestContacts', 0)
        ,@('HKCU:\Software\Microsoft\Personalization\Settings', 'AcceptedPrivacyPolicy', 0)
    )
    if (-not ('Dotfiles.SelectedPreferences' -as [type])) {
        Add-Type -Namespace Dotfiles -Name SelectedPreferences -MemberDefinition @'
[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
private struct StickyKeys { public uint Size; public uint Flags; }
[System.Runtime.InteropServices.DllImport("user32.dll", EntryPoint="SystemParametersInfoW", SetLastError=true)]
private static extern bool Read(uint action, uint parameter, out int value, uint flags);
[System.Runtime.InteropServices.DllImport("user32.dll", EntryPoint="SystemParametersInfoW", SetLastError=true)]
private static extern bool Write(uint action, uint parameter, System.IntPtr value, uint flags);
[System.Runtime.InteropServices.DllImport("user32.dll", EntryPoint="SystemParametersInfoW", SetLastError=true)]
private static extern bool Sticky(uint action, uint parameter, ref StickyKeys value, uint flags);
[System.Runtime.InteropServices.DllImport("user32.dll", CharSet=System.Runtime.InteropServices.CharSet.Unicode)]
private static extern System.IntPtr SendMessageTimeout(System.IntPtr hwnd, uint message,
    System.UIntPtr wparam, string lparam, uint flags, uint timeout, out System.UIntPtr result);
private static void Check(bool success) {
    if (!success) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
}
public static bool WindowArrangingEnabled() {
    int value; Check(Read(0x0082, 0, out value, 0)); return value != 0;
}
public static void DisableWindowArranging() {
    Check(Write(0x0083, 0, System.IntPtr.Zero, 3));
}
public static uint StickyFlags() {
    var value = new StickyKeys { Size = 8 };
    Check(Sticky(0x003A, value.Size, ref value, 0)); return value.Flags;
}
public static void DisableStickyShortcut() {
    // Clear only SKF_HOTKEYACTIVE; retain the enabled/accessibility and other flags.
    var value = new StickyKeys { Size = 8, Flags = StickyFlags() & ~4u };
    Check(Sticky(0x003B, value.Size, ref value, 3));
}
public static void Notify() {
    System.UIntPtr result;
    foreach (var area in new [] { "ImmersiveColorSet", "TraySettings" }) {
        SendMessageTimeout(new System.IntPtr(0xffff), 0x001a, System.UIntPtr.Zero, area, 2, 500, out result);
    }
}
'@
    }
} elseif ($Context -eq 'UserPolicy') {
    # WinGet elevates this resource as the same account; ordinary HKCU preferences stay unelevated.
    # Existing user policy keys can be administrator-owned. Do not change their ownership or ACLs.
    $rows = @(,@('HKCU:\Software\Policies\Microsoft\Windows\Explorer', 'DisableSearchBoxSuggestions', 1))
} else {
    $rows = @(
        # Keep the activity feed available for clipboard history, but stop publishing/uploading.
        ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\System', 'EnableActivityFeed', 1)
        ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\System', 'PublishUserActivities', 0)
        ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\System', 'UploadUserActivities', 0)
        ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata', 'PreventDeviceMetadataFromNetwork', 1)
        ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors', 'DisableLocation', 1)
        ,@('HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice', 'AllowFindMyDevice', 0)
        ,@('HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization', 'AllowInputPersonalization', 0)
        ,@('HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem', 'LongPathsEnabled', 1)
        ,@('HKLM:\SOFTWARE\Policies\WindowsNotepad', 'DisableAIFeatures', 1)
    )
    # https://learn.microsoft.com/windows/client-management/mdm/policy-csp-windowsai
    $paintSupported = $version.EditionID -match '^(Professional|Enterprise|Education|IoTEnterprise)' -and (
        $build -gt 26100 -or ($build -eq 26100 -and [int]$version.UBR -ge 3360) -or
        ($build -in @(22621, 22631) -and [int]$version.UBR -ge 4870))
    if ($paintSupported) {
        foreach ($name in @('DisableCocreator', 'DisableGenerativeFill', 'DisableImageCreator')) {
            $rows += ,@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint', $name, 1)
        }
    } else { $unsupported += 'The documented Paint AI policies are not supported on this build/edition.' }
    $unsupported += 'Paint generative erase/background removal has no verified policy in the examined Microsoft policy definitions; these controls are not forced.'
}
$settings = @($rows | ForEach-Object { @{ Path=$_[0]; Name=$_[1]; Value=$_[2]; Kind='DWord' } })
function Get-SelectedState {
    $state = @{ Settings=@($settings | ForEach-Object { @{ Path=$_.Path; Name=$_.Name; Matches=[bool](Test-RegistrySetting $_) } }); Unsupported=$unsupported }
    if ($Context -eq 'User') {
        $state.WindowArrangingDisabled = -not [Dotfiles.SelectedPreferences]::WindowArrangingEnabled()
        $state.StickyShortcutDisabled = ([Dotfiles.SelectedPreferences]::StickyFlags() -band 4) -eq 0
    } elseif ($Context -eq 'Machine') {
        $service = Get-Service -Name DiagTrack -ErrorAction Stop
        $state.DiagTrackDisabled = $service.StartType -eq 'Disabled' -and $service.Status -eq 'Stopped'
    }
    $state
}
function Test-SelectedState($State) {
    if (@($State.Settings | Where-Object { -not $_.Matches }).Count) { return $false }
    if ($Context -eq 'User') { return $State.WindowArrangingDisabled -and $State.StickyShortcutDisabled }
    if ($Context -eq 'Machine') { return $State.DiagTrackDisabled }
    $true
}
foreach ($message in $unsupported) { Write-Warning $message }
switch ($Operation) {
    Get { Get-SelectedState }
    Test { Test-SelectedState (Get-SelectedState) }
    Set {
        $failures = [Collections.Generic.List[string]]::new()
        foreach ($setting in $settings) {
            try {
                if (Test-RegistrySetting $setting) { continue }
                if (-not (Test-Path -LiteralPath $setting.Path)) { [void](New-Item -Path $setting.Path -Force -ErrorAction Stop) }
                [void](New-ItemProperty -LiteralPath $setting.Path -Name $setting.Name -Value $setting.Value -PropertyType $setting.Kind -Force -ErrorAction Stop)
                if (-not (Test-RegistrySetting $setting)) { throw 'Windows did not retain the requested value.' }
            } catch { $failures.Add("$($setting.Path)\$($setting.Name): $($_.Exception.Message)") }
        }
        try {
            if ($Context -eq 'User') {
                if ([Dotfiles.SelectedPreferences]::WindowArrangingEnabled()) { [Dotfiles.SelectedPreferences]::DisableWindowArranging() }
                if ([Dotfiles.SelectedPreferences]::StickyFlags() -band 4) { [Dotfiles.SelectedPreferences]::DisableStickyShortcut() }
                [Dotfiles.SelectedPreferences]::Notify()
            } elseif ($Context -eq 'Machine') {
                $service = Get-Service -Name DiagTrack -ErrorAction Stop
                if ($service.StartType -ne 'Disabled') { Set-Service -Name DiagTrack -StartupType Disabled -ErrorAction Stop }
                if ($service.Status -ne 'Stopped') { Stop-Service -Name DiagTrack -ErrorAction Stop }
            }
            if (-not (Test-SelectedState (Get-SelectedState))) { throw 'Selected preferences did not converge; inspect Operation Get.' }
        } catch { $failures.Add($_.Exception.Message) }
        if ($failures.Count) { throw "Some selected preferences could not be applied. $($failures -join ' ')" }
    }
}
