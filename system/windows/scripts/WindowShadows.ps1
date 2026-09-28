param(
    [ValidateSet('Get', 'Set')][string]$Operation = 'Get',
    [bool]$Enabled = $false
)

$ErrorActionPreference = 'Stop'
if (-not ('Dotfiles.WindowShadows' -as [type])) {
    Add-Type -Namespace Dotfiles -Name WindowShadows -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", EntryPoint = "SystemParametersInfoW")]
public static extern bool Get(uint action, uint parameter, out int value, uint flags);
[System.Runtime.InteropServices.DllImport("user32.dll", EntryPoint = "SystemParametersInfoW")]
public static extern bool Set(uint action, uint parameter, System.IntPtr value, uint flags);
'@
}

if ($Operation -eq 'Set') {
    if (-not [Dotfiles.WindowShadows]::Set(0x1025, 0, [IntPtr]([int]$Enabled), 3)) {
        throw 'Could not update the Windows drop-shadow preference.'
    }
}

$value = 0
if (-not [Dotfiles.WindowShadows]::Get(0x1024, 0, [ref]$value, 0)) {
    throw 'Could not read the Windows drop-shadow preference.'
}
if ($Operation -eq 'Set' -and [bool]$value -ne $Enabled) {
    throw 'Windows did not retain the requested drop-shadow preference.'
}
[bool]$value
