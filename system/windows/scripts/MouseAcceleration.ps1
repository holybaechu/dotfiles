#requires -Version 7.0

param(
    [ValidateSet('Get', 'Set')][string]$Operation = 'Get',
    [bool]$Enabled = $false
)

$ErrorActionPreference = 'Stop'
if (-not ('Dotfiles.MouseAcceleration' -as [type])) {
    Add-Type -Namespace Dotfiles -Name MouseAcceleration -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", EntryPoint = "SystemParametersInfoW")]
public static extern bool SystemParametersInfo(uint action, uint parameter,
    [System.Runtime.InteropServices.In, System.Runtime.InteropServices.Out] int[] values, uint flags);
'@
}

# SPI_GETMOUSE returns two thresholds followed by the acceleration setting.
$values = [int[]]::new(3)
if (-not [Dotfiles.MouseAcceleration]::SystemParametersInfo(0x0003, 0, $values, 0)) {
    throw 'Could not read the Windows mouse acceleration preference.'
}
if ($Operation -eq 'Set' -and [bool]$values[2] -ne $Enabled) {
    # Keep the thresholds and pointer speed; only toggle Enhance pointer precision.
    $values[2] = [int]$Enabled
    # SPI_SETMOUSE with SPIF_UPDATEINIFILE | SPIF_SENDCHANGE persists and applies it.
    if (-not [Dotfiles.MouseAcceleration]::SystemParametersInfo(0x0004, 0, $values, 3)) {
        throw 'Could not update the Windows mouse acceleration preference.'
    }
    if (-not [Dotfiles.MouseAcceleration]::SystemParametersInfo(0x0003, 0, $values, 0)) {
        throw 'Could not read the Windows mouse acceleration preference.'
    }
    if ([bool]$values[2] -ne $Enabled) {
        throw 'Windows did not retain the requested mouse acceleration preference.'
    }
}
[bool]$values[2]
