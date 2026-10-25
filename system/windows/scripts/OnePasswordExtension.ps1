#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Get', 'Test', 'Set')][string]$Operation = 'Test'
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\RegistryState.ps1"

# Aside's Windows build reads Chromium's shared Google\Chrome extension key.
$setting = @{
    Path = 'HKLM:\Software\WOW6432Node\Google\Chrome\Extensions\aeblfdkhhhdcdjpifhhbdiojplfjncoa'
    Name = 'update_url'
    Kind = 'String'
    Value = 'https://clients2.google.com/service/update2/crx'
}
if ($Operation -eq 'Get') { return Get-RegistryState $setting }
if ($Operation -eq 'Test') { return Test-RegistrySetting $setting }
if (Test-RegistrySetting $setting) { return }

if (-not (Test-Path -LiteralPath $setting.Path)) { [void](New-Item -Path $setting.Path -Force) }
[void](New-ItemProperty -LiteralPath $setting.Path -Name $setting.Name -Value $setting.Value -PropertyType $setting.Kind -Force)
if (-not (Test-RegistrySetting $setting)) {
    throw 'Windows did not retain the 1Password extension registration for Aside.'
}
