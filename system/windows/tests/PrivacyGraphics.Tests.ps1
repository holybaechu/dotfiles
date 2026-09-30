#requires -Version 7.0
# Registry writes and DxDiag are mocked; only temporary journal files are written.
$ErrorActionPreference = 'Stop'
$scripts = Join-Path (Split-Path $PSScriptRoot) 'scripts'
$global:SettingsFixture = @{ Registry = @{}; Writes = 0; Deny = $false; Hardware = 'DriverSupportState:Stable Enabled:True' }
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-settings-test-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $scratch)
$savedLocal = $env:LOCALAPPDATA
$savedProgram = $env:ProgramData

function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Test-Path {
    [CmdletBinding()]param([string]$LiteralPath)
    if ($LiteralPath -match '^HK(CU|LM):') { return $global:SettingsFixture.Registry.ContainsKey($LiteralPath) }
    Microsoft.PowerShell.Management\Test-Path -LiteralPath $LiteralPath
}
function Get-Item {
    [CmdletBinding()]param([string]$LiteralPath)
    $item = [pscustomobject]@{ Data = $global:SettingsFixture.Registry[$LiteralPath] }
    $item | Add-Member ScriptMethod GetValueNames { @($this.Data.Keys) }
    $item | Add-Member ScriptMethod GetValueKind { param($name) $this.Data[$name].Kind }
    $item | Add-Member ScriptMethod GetValue { param($name,$default,$options) $this.Data[$name].Value }
    $item
}
function Get-ItemProperty {
    [CmdletBinding()]param([string]$Path)
    @{ CurrentBuild = '26200'; UBR = 9457; EditionID = 'Professional' }
}
function New-Item {
    [CmdletBinding()]param([string]$Path,[string]$ItemType,[switch]$Force)
    if ($Path -match '^HK(CU|LM):') {
        Assert (-not $global:SettingsFixture.Registry.ContainsKey($Path)) 'Existing registry keys must not be recreated.'
        $global:SettingsFixture.Registry[$Path] = @{}
    } else { Microsoft.PowerShell.Management\New-Item @PSBoundParameters }
}
function New-ItemProperty {
    [CmdletBinding()]param([string]$LiteralPath,[string]$Name,$Value,[string]$PropertyType,[switch]$Force)
    if ($global:SettingsFixture.Deny) { throw 'Registry access denied.' }
    $global:SettingsFixture.Writes++
    $global:SettingsFixture.Registry[$LiteralPath][$Name] = @{ Value=$Value; Kind=$PropertyType }
}
function Remove-ItemProperty {
    [CmdletBinding()]param([string]$LiteralPath,[string]$Name)
    $global:SettingsFixture.Registry[$LiteralPath].Remove($Name)
}
function Start-Process {
    param($FilePath,$ArgumentList,$WindowStyle,[switch]$PassThru)
    Assert ($FilePath -like '*dxdiag.exe') 'Only DxDiag may be launched by this fixture.'
    $path = $ArgumentList[-1].Trim('"')
    [IO.File]::WriteAllText($path,"<DxDiag><DisplayDevices><DisplayDevice><CardName>Fixture GPU</CardName><HardwareSchedulingAttributes>$($global:SettingsFixture.Hardware)</HardwareSchedulingAttributes></DisplayDevice></DisplayDevices></DxDiag>")
    $process = [pscustomobject]@{ ExitCode = 0 }
    $process | Add-Member ScriptMethod WaitForExit { param($timeout) $true }
    $process | Add-Member ScriptMethod Dispose { }
    $process
}
try {
    $env:LOCALAPPDATA = $scratch
    $env:ProgramData = $scratch
    $privacy = Join-Path $scripts 'Privacy.ps1'
    $graphics = Join-Path $scripts 'Graphics.ps1'
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
    $global:SettingsFixture.Registry[$key] = @{ Enabled=@{Kind='DWord';Value=1}; Retain=@{Kind='String';Value='sentinel'} }
    $state = & $privacy -Operation Get -Context User -WarningAction SilentlyContinue
    Assert ($state.Settings.Count -eq 17 -and $state.Unsupported.Count -eq 1) 'Privacy settings must remain structured and report Pro limitations.'
    Assert (@($state.Settings | Where-Object { $_.Path -like 'HKCU:\Software\Policies\*' }).Count -eq 0) 'Normal-user preferences must not require writes to administrator-owned policy keys.'
    Assert ($global:SettingsFixture.Writes -eq 0) 'Get must not write.'
    & $privacy -Operation Set -Context User
    Assert (& $privacy -Operation Test -Context User) 'Privacy apply must converge.'
    $writes = $global:SettingsFixture.Writes
    & $privacy -Operation Set -Context User
    Assert ($global:SettingsFixture.Writes -eq $writes) 'Privacy reapply must not write.'
    & $privacy -Operation Restore -Context User
    Assert ($global:SettingsFixture.Registry[$key].Enabled.Value -eq 1) 'Restore original value, not a guessed default.'
    Assert ($global:SettingsFixture.Registry[$key].Retain.Value -eq 'sentinel') 'Preserve unrelated values.'
    Assert (-not $global:SettingsFixture.Registry['HKCU:\System\GameConfigStore'].ContainsKey('GameDVR_Enabled')) 'Remove only values introduced by the change.'
    Write-Output 'PASS: privacy read-only checks, convergence, journal retention, and restoration'

    $gpuKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    $global:SettingsFixture.Registry[$gpuKey] = @{ DirectXUserGlobalSettings=@{Kind='String';Value='VRROptimizeEnable=1;AutoHDREnable=0;SwapEffectUpgradeEnable=0;'} }
    & $graphics -Operation Set -Context User
    $value = $global:SettingsFixture.Registry[$gpuKey].DirectXUserGlobalSettings.Value
    Assert ($value -match 'VRROptimizeEnable=1;' -and $value -match 'AutoHDREnable=0;' -and $value -match 'SwapEffectUpgradeEnable=1;') 'Enable only the selected graphics token.'
    $global:SettingsFixture.Registry[$gpuKey].DirectXUserGlobalSettings.Value = $value.Replace('VRROptimizeEnable=1','VRROptimizeEnable=0') + 'Other=keep;'
    & $graphics -Operation Restore -Context User
    $value = $global:SettingsFixture.Registry[$gpuKey].DirectXUserGlobalSettings.Value
    Assert ($value -match 'SwapEffectUpgradeEnable=0;' -and $value -match 'VRROptimizeEnable=0;' -and $value -match 'Other=keep;') 'Rollback must preserve subsequent VRR/other changes.'
    Write-Output 'PASS: windowed-game enablement and rollback preserve VRR, HDR, and unrelated tokens'

    Assert ((& $graphics -Operation Get -Context Machine).Status -eq 'Enabled') 'Read active HAGS from hardware report.'
    $global:SettingsFixture.Hardware = 'DriverSupportState:Stable Enabled:False'
    & $graphics -Operation Set -Context Machine -WarningAction SilentlyContinue
    Assert ((& $graphics -Operation Get -Context Machine).Status -eq 'RestartPending') 'A registry value is not proof of active HAGS.'
    $global:SettingsFixture.Hardware = 'DriverSupportState:Unknown Enabled:False'
    $writes = $global:SettingsFixture.Writes
    $caught = $false
    try { & $graphics -Operation Set -Context Machine } catch { $caught = $_.Exception.Message -like '*support could not be confirmed*' }
    Assert ($caught -and $global:SettingsFixture.Writes -eq $writes) 'Unsupported HAGS must never be forced.'
    $global:SettingsFixture.Deny = $true
    $caught = $false
    try { & $privacy -Operation Set -Context Machine } catch { $caught = $_.Exception.Message -like '*access denied*' }
    Assert $caught 'Denied writes must not be reported as successful.'
    Write-Output 'PASS: active versus pending HAGS, unsupported hardware, and denied writes'
} finally {
    $env:LOCALAPPDATA = $savedLocal
    $env:ProgramData = $savedProgram
    # Delete only this verified, generated fixture directory.
    $resolved = [IO.Path]::GetFullPath($scratch)
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $resolved.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'dotfiles-settings-test-*') { throw 'Unsafe fixture cleanup path.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
    Remove-Variable SettingsFixture -Scope Global
}
