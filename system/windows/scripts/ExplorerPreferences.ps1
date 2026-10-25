#requires -Version 7.0

param(
    [ValidateSet('Get', 'Set')][string]$Operation = 'Get',
    [bool]$HideDesktopIcons = $true,
    [bool]$ShowHiddenFiles = $true,
    [bool]$ShowFileExtensions = $true
)

$ErrorActionPreference = 'Stop'
if (-not ('Dotfiles.ExplorerPreferences' -as [type])) {
    Add-Type -Namespace Dotfiles -Name ExplorerPreferences -MemberDefinition @'
// SHELLSTATE is 32 bytes; the settings below are in its first bitfield.
[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Explicit, Size = 32)]
public struct ShellState {
    [System.Runtime.InteropServices.FieldOffset(0)] public uint Flags;
}
[System.Runtime.InteropServices.DllImport("shell32.dll")]
public static extern void SHGetSetSettings(ref ShellState state, uint mask, bool set);
[System.Runtime.InteropServices.DllImport("user32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern System.IntPtr SendMessageTimeout(System.IntPtr hwnd, uint message,
    System.UIntPtr wparam, string lparam, uint flags, uint timeout, out System.UIntPtr result);
'@
}

# SSF_SHOWALLOBJECTS | SSF_SHOWEXTENSIONS | SSF_HIDEICONS.
$mask = 0x4003
$state = New-Object 'Dotfiles.ExplorerPreferences+ShellState'
[Dotfiles.ExplorerPreferences]::SHGetSetSettings([ref]$state, $mask, $false)
if ($Operation -eq 'Set') {
    $desired = ([int]$ShowHiddenFiles) -bor ([int]$ShowFileExtensions -shl 1) -bor ([int]$HideDesktopIcons -shl 12)
    $state.Flags = ($state.Flags -band (-bnot 0x1003)) -bor $desired
    [Dotfiles.ExplorerPreferences]::SHGetSetSettings([ref]$state, $mask, $true)
    $result = [UIntPtr]::Zero
    [void][Dotfiles.ExplorerPreferences]::SendMessageTimeout([IntPtr]0xffff, 0x1a,
        [UIntPtr]::Zero, 'ShellState', 2, 1000, [ref]$result)
    [Dotfiles.ExplorerPreferences]::SHGetSetSettings([ref]$state, $mask, $false)
    if (($state.Flags -band 0x1003) -ne $desired) {
        throw 'Windows did not retain the requested Explorer preferences.'
    }
}
[pscustomobject]@{
    HideDesktopIcons = [bool]($state.Flags -band 0x1000)
    ShowHiddenFiles = [bool]($state.Flags -band 1)
    ShowFileExtensions = [bool]($state.Flags -band 2)
}
