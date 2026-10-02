#requires -Version 7.0
[CmdletBinding()]
param([ValidateSet('Get', 'Test', 'Set')][string]$Operation = 'Test')
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\RegistryState.ps1"

# Canopy's #7cab3d accent. DWM/Explorer use ABGR; ColorizationColor uses ARGB.
# https://learn.microsoft.com/openspecs/windows_protocols/ms-rdperp/bc6975ee-c630-4414-ba10-04eecbb6fccc
$accent = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
$dwm = 'HKCU:\Software\Microsoft\Windows\DWM'
$rows = @(
    ,@($accent, 'AccentColorMenu', 0xff3dab7c)
    ,@($accent, 'StartColorMenu', 0xff318a63)
    ,@($dwm, 'AccentColor', 0xff3dab7c)
    ,@($dwm, 'ColorizationColor', 0xff7cab3d)
    ,@($dwm, 'ColorizationAfterglow', 0xff7cab3d)
    ,@('HKCU:\Control Panel\Desktop', 'AutoColorization', 0)
)
$settings = @($rows | ForEach-Object { @{ Path=$_[0]; Name=$_[1]; Value=$_[2]; Kind='DWord' } })
# Seven light-to-dark accent shades plus the final auxiliary color, each RGB + padding.
$settings += @{ Path=$accent; Name='AccentPalette'; Kind='Binary'; Value=[Convert]::FromHexString(
    'd0e7b200bfdc960092bd56007cab3d00638a31004d6d2500344b1900ebc98a00') }

function Get-AccentState {
    @{ Color='#7cab3d'; Settings=@($settings | ForEach-Object {
        @{ Path=$_.Path; Name=$_.Name; Matches=[bool](Test-RegistrySetting $_) }
    }) }
}
function Test-AccentState {
    @((Get-AccentState).Settings | Where-Object { -not $_.Matches }).Count -eq 0
}
switch ($Operation) {
    Get { Get-AccentState }
    Test { Test-AccentState }
    Set {
        $changed = $false
        foreach ($setting in $settings) {
            if (Test-RegistrySetting $setting) { continue }
            if (-not (Test-Path -LiteralPath $setting.Path)) { [void](New-Item -Path $setting.Path -Force -ErrorAction Stop) }
            [void](New-ItemProperty -LiteralPath $setting.Path -Name $setting.Name -Value $setting.Value -PropertyType $setting.Kind -Force -ErrorAction Stop)
            if (-not (Test-RegistrySetting $setting)) { throw "Windows did not retain $($setting.Name)." }
            $changed = $true
        }
        if ($changed) {
            if (-not ('Dotfiles.AccentColor' -as [type])) {
                Add-Type -Namespace Dotfiles -Name AccentColor -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", CharSet=System.Runtime.InteropServices.CharSet.Unicode)]
private static extern System.IntPtr SendMessageTimeout(System.IntPtr hwnd, uint message,
    System.UIntPtr wparam, string lparam, uint flags, uint timeout, out System.UIntPtr result);
public static void Notify() {
    System.UIntPtr result;
    SendMessageTimeout(new System.IntPtr(0xffff), 0x001a, System.UIntPtr.Zero, "ImmersiveColorSet", 2, 500, out result);
}
'@
            }
            [Dotfiles.AccentColor]::Notify()
        }
        if (-not (Test-AccentState)) { throw 'Windows accent did not converge; inspect Operation Get.' }
    }
}
