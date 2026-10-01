#requires -Version 7.0
[CmdletBinding()]
param([ValidateSet('Get', 'Test', 'Set', 'Restore')][string]$Operation = 'Test')
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\RegistryState.ps1"

if (-not ('Dotfiles.VisualEffects' -as [type])) {
    Add-Type -Namespace Dotfiles -Name VisualEffects -MemberDefinition @'
[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
private struct AnimationInfo { public uint Size; public int Minimize; }
[System.Runtime.InteropServices.DllImport("user32.dll", EntryPoint="SystemParametersInfoW", SetLastError=true)]
private static extern bool Get(uint action, uint parameter, out int value, uint flags);
[System.Runtime.InteropServices.DllImport("user32.dll", EntryPoint="SystemParametersInfoW", SetLastError=true)]
private static extern bool Set(uint action, uint parameter, System.IntPtr value, uint flags);
[System.Runtime.InteropServices.DllImport("user32.dll", EntryPoint="SystemParametersInfoW", SetLastError=true)]
private static extern bool Animation(uint action, uint parameter, ref AnimationInfo value, uint flags);
[System.Runtime.InteropServices.DllImport("user32.dll", CharSet=System.Runtime.InteropServices.CharSet.Unicode)]
private static extern System.IntPtr SendMessageTimeout(System.IntPtr hwnd, uint message,
    System.UIntPtr wparam, string lparam, uint flags, uint timeout, out System.UIntPtr result);
private static void Check(bool success) {
    if (!success) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
}
public static bool Read(uint action) {
    if (action == 0x0048) {
        var value = new AnimationInfo { Size = 8 };
        Check(Animation(action, value.Size, ref value, 0));
        return value.Minimize != 0;
    }
    int enabled;
    Check(Get(action, 0, out enabled, 0));
    return enabled != 0;
}
public static void Write(uint action, bool enabled) {
    // SPIF_UPDATEINIFILE | SPIF_SENDCHANGE persists the specific preference and broadcasts it.
    if (action == 0x0049) {
        var value = new AnimationInfo { Size = 8, Minimize = enabled ? 1 : 0 };
        Check(Animation(action, value.Size, ref value, 3));
    } else {
        Check(Set(action, 0, new System.IntPtr(enabled ? 1 : 0), 3));
    }
}
public static void Notify() {
    System.UIntPtr result;
    foreach (var area in new [] { "ImmersiveColorSet", "TraySettings" }) {
        SendMessageTimeout(new System.IntPtr(0xffff), 0x001a, System.UIntPtr.Zero, area, 2, 500, out result);
    }
}
'@
}

# Use individual Windows APIs, not a replacement UserPreferencesMask or a visual-effects preset.
# https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-systemparametersinfow
$animations = @(
    @{ Name='ClientArea'; Get=0x1042; Set=0x1043 }
    @{ Name='MinimizeMaximize'; Get=0x0048; Set=0x0049 }
    @{ Name='Menu'; Get=0x1002; Set=0x1003 }
    @{ Name='ComboBox'; Get=0x1004; Set=0x1005 }
    @{ Name='ListBoxSmoothScroll'; Get=0x1006; Set=0x1007 }
    @{ Name='SelectionFade'; Get=0x1014; Set=0x1015 }
    @{ Name='Tooltip'; Get=0x1016; Set=0x1017 }
)
$settings = @(
    @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='TaskbarAnimations'; Kind='DWord'; Value=0 }
    @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name='EnableTransparency'; Kind='DWord'; Value=1 }
)
$journalPath = Join-Path $env:LOCALAPPDATA 'dotfiles\rollback\visual-effects-user.json'
function Get-VisualState {
    $enabled = @($animations | Where-Object { [Dotfiles.VisualEffects]::Read($_.Get) } | ForEach-Object Name)
    [pscustomobject]@{
        EnabledAnimations = $enabled
        AnimationsDisabled = $enabled.Count -eq 0 -and (Test-RegistrySetting $settings[0])
        TransparencyEnabled = [bool](Test-RegistrySetting $settings[1])
    }
}
switch ($Operation) {
    Get { Get-VisualState }
    Test { $state = Get-VisualState; $state.AnimationsDisabled -and $state.TransparencyEnabled }
    Set {
        $journal = Read-RegistryJournal $journalPath
        foreach ($animation in $animations) {
            $current = [Dotfiles.VisualEffects]::Read($animation.Get)
            if (-not $current) { continue }
            $id = 'Animation:' + $animation.Name
            if (-not $journal.ContainsKey($id)) {
                $journal[$id] = $current
                Save-RegistryJournal $journalPath $journal
            }
            [Dotfiles.VisualEffects]::Write($animation.Set, $false)
            if ([Dotfiles.VisualEffects]::Read($animation.Get)) { throw "Windows did not disable $($animation.Name) animations." }
        }
        foreach ($setting in $settings) { Set-TrackedRegistryValue $setting $journalPath }
        [Dotfiles.VisualEffects]::Notify()
        $state = Get-VisualState
        if (-not ($state.AnimationsDisabled -and $state.TransparencyEnabled)) { throw 'Windows did not retain the requested visual settings.' }
    }
    Restore {
        # Restore only these named preferences, preserving unrelated or later visual changes.
        Restore-RegistryValues $settings $journalPath
        $journal = Read-RegistryJournal $journalPath
        foreach ($animation in $animations) {
            $id = 'Animation:' + $animation.Name
            if (-not $journal.ContainsKey($id)) { continue }
            if ($journal[$id] -isnot [bool]) { throw "Invalid rollback value for $id." }
            [Dotfiles.VisualEffects]::Write($animation.Set, $journal[$id])
            if ([Dotfiles.VisualEffects]::Read($animation.Get) -ne $journal[$id]) { throw "Restore verification failed: $id" }
            $journal.Remove($id)
            Save-RegistryJournal $journalPath $journal
        }
        [Dotfiles.VisualEffects]::Notify()
    }
}
