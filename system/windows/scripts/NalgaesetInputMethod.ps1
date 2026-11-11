#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Get', 'Test', 'Set')][string]$Operation = 'Test'
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\RegistryState.ps1"

$tip = '0412:{5CC2EDB1-F5F4-456C-A871-CF6B62415CD9}{36207E64-3175-433E-A713-2D0F7473273A}'
$microsoftTip = '0412:{A028AE76-01B1-46C2-99C4-ACD9858AE02F}{B5FE1F02-D5F2-4445-9C03-C568F23C99A1}'
$profileKey = 'HKLM:\SOFTWARE\Microsoft\CTF\TIP\{5CC2EDB1-F5F4-456C-A871-CF6B62415CD9}\LanguageProfile\0x00000412\{36207E64-3175-433E-A713-2D0F7473273A}'
$installed = Test-Path -LiteralPath $profileKey
$languages = Get-WinUserLanguageList
$korean = $languages | Where-Object { $_.LanguageTag -in @('ko', 'ko-KR') } | Select-Object -First 1
$enabled = $korean -and $tip -in $korean.InputMethodTips
$matchingInputMethods = $enabled -and $languages.Count -eq 1 -and $korean.InputMethodTips.Count -eq 2 -and $microsoftTip -in $korean.InputMethodTips
$keyboardCorrection = @{ Path = 'HKCU:\Software\YMSoft\NgsEdit\Settings'; Name = 'KbdDriverModifier'; Kind = 'DWord'; Value = 3 }
# Nalgaeset's "recognize Alt+= as-is" option prevents the width-toggle shortcut.
$widthShortcutDisabled = Test-RegistrySetting $keyboardCorrection
$default = (Get-WinDefaultInputMethodOverride).InputMethodTip
if ($Operation -eq 'Get') { return @{ Installed = $installed; Enabled = [bool]$enabled; InputMethodsMatch = [bool]$matchingInputMethods; WidthShortcutDisabled = $widthShortcutDisabled; DefaultInputMethod = $default } }
if ($Operation -eq 'Test') { return $installed -and $matchingInputMethods -and $widthShortcutDisabled -and $default -eq $tip }
if (-not $installed) { throw 'Install Nalgaeset through the packages module before selecting its input method.' }

if (-not $matchingInputMethods) {
    if (-not $korean) {
        $korean = (New-WinUserLanguageList -Language 'ko-KR')[0]
        $languages.Add($korean)
    }
    $korean.InputMethodTips.Clear()
    $korean.InputMethodTips.Add($tip)
    $korean.InputMethodTips.Add($microsoftTip)
    for ($index = $languages.Count - 1; $index -ge 0; $index--) {
        if ($languages[$index] -ne $korean) { $languages.RemoveAt($index) }
    }
    Set-WinUserLanguageList -LanguageList $languages -Force
}
if (-not $widthShortcutDisabled) {
    if (-not (Test-Path -LiteralPath $keyboardCorrection.Path)) { [void](New-Item -Path $keyboardCorrection.Path -Force) }
    [void](New-ItemProperty -LiteralPath $keyboardCorrection.Path -Name $keyboardCorrection.Name -Value $keyboardCorrection.Value -PropertyType $keyboardCorrection.Kind -Force)
}
if ((Get-WinDefaultInputMethodOverride).InputMethodTip -ne $tip) {
    Set-WinDefaultInputMethodOverride -InputTip $tip
}
if (-not (& $PSCommandPath -Operation Test)) {
    throw 'Windows did not retain Nalgaeset with Microsoft IME and the disabled width shortcut.'
}
