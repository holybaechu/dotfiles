#requires -Version 7.0
[CmdletBinding()]
param([ValidateSet('Get', 'Test', 'Set')][string]$Operation = 'Test')
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

# The Windows minimize/maximize preference (documented as minimize/restore).
# https://learn.microsoft.com/windows/win32/api/winuser/ns-winuser-animationinfo
$transparency = @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name='EnableTransparency'; Kind='DWord'; Value=1 }

function Get-VisualState {
    [pscustomobject]@{
        WindowAnimationsDisabled = -not [Dotfiles.VisualEffects]::Read(0x0048)
        TransparencyEnabled = [bool](Test-RegistrySetting $transparency)
    }
}

switch ($Operation) {
    Get { Get-VisualState }
    Test { $state = Get-VisualState; $state.WindowAnimationsDisabled -and $state.TransparencyEnabled }
    Set {
        if ([Dotfiles.VisualEffects]::Read(0x0048)) {
            [Dotfiles.VisualEffects]::Write(0x0049, $false)
            if ([Dotfiles.VisualEffects]::Read(0x0048)) { throw 'Windows did not disable minimize/maximize animations.' }
        }
        Set-RegistrySetting $transparency
        [Dotfiles.VisualEffects]::Notify()
        $state = Get-VisualState
        if (-not ($state.WindowAnimationsDisabled -and $state.TransparencyEnabled)) { throw 'Windows did not retain the requested visual settings.' }
    }
}
