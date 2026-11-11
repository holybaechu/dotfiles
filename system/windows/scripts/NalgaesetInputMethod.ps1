#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Get', 'Test', 'Set')][string]$Operation = 'Test'
)
$ErrorActionPreference = 'Stop'

$tip = '0412:{5CC2EDB1-F5F4-456C-A871-CF6B62415CD9}{36207E64-3175-433E-A713-2D0F7473273A}'
$profileKey = 'HKLM:\SOFTWARE\Microsoft\CTF\TIP\{5CC2EDB1-F5F4-456C-A871-CF6B62415CD9}\LanguageProfile\0x00000412\{36207E64-3175-433E-A713-2D0F7473273A}'
$installed = Test-Path -LiteralPath $profileKey
$languages = Get-WinUserLanguageList
$korean = $languages | Where-Object { $_.LanguageTag -in @('ko', 'ko-KR') } | Select-Object -First 1
$enabled = $korean -and $tip -in $korean.InputMethodTips
$onlyNalgaeset = $enabled -and $languages.Count -eq 1 -and $korean.InputMethodTips.Count -eq 1
$default = (Get-WinDefaultInputMethodOverride).InputMethodTip
if ($Operation -eq 'Get') { return @{ Installed = $installed; Enabled = [bool]$enabled; OnlyNalgaeset = [bool]$onlyNalgaeset; DefaultInputMethod = $default } }
if ($Operation -eq 'Test') { return $installed -and $onlyNalgaeset -and $default -eq $tip }
if (-not $installed) { throw 'Install Nalgaeset through the packages module before selecting its input method.' }

if (-not $onlyNalgaeset) {
    if (-not $korean) {
        $korean = (New-WinUserLanguageList -Language 'ko-KR')[0]
        $languages.Add($korean)
    }
    $korean.InputMethodTips.Clear()
    $korean.InputMethodTips.Add($tip)
    for ($index = $languages.Count - 1; $index -ge 0; $index--) {
        if ($languages[$index] -ne $korean) { $languages.RemoveAt($index) }
    }
    Set-WinUserLanguageList -LanguageList $languages -Force
}
if ((Get-WinDefaultInputMethodOverride).InputMethodTip -ne $tip) {
    Set-WinDefaultInputMethodOverride -InputTip $tip
}
if (-not (& $PSCommandPath -Operation Test)) {
    throw 'Windows did not retain Nalgaeset as the only enabled, default input method.'
}
