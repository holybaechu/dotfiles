#requires -Version 7.0
# Registry writes, visual-effects APIs, and DxDiag are mocked; only temporary journal files are written.
$ErrorActionPreference = 'Stop'
$scripts = Join-Path (Split-Path $PSScriptRoot) 'scripts'
$global:SettingsFixture = @{ Registry = @{}; Writes = 0; Deny = $false; Hardware = 'DriverSupportState:Stable Enabled:True'; Edition = 'Professional' }
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-settings-test-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $scratch)
$savedLocal = $env:LOCALAPPDATA
$savedProgram = $env:ProgramData
if ('Dotfiles.VisualEffects' -as [type]) { throw 'Run this fixture in a fresh PowerShell process.' }
Add-Type -Namespace Dotfiles -Name VisualEffects -MemberDefinition @'
public static System.Collections.Generic.Dictionary<uint, bool> Values = new System.Collections.Generic.Dictionary<uint, bool>();
public static int Writes = 0;
public static bool Deny = false;
public static bool Read(uint action) { return Values.ContainsKey(action) ? Values[action] : true; }
public static void Write(uint action, bool enabled) {
    if (Deny) throw new System.InvalidOperationException("Visual preference access denied.");
    Writes++;
    Values[action - 1] = enabled;
}
public static void Notify() { }
'@

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
    @{ CurrentBuild = '26200'; UBR = 9457; EditionID = $global:SettingsFixture.Edition }
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

    $visual = Join-Path $scripts 'VisualEffects.ps1'
    $personalize = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    $advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $global:SettingsFixture.Registry[$personalize] = @{ EnableTransparency=@{Kind='DWord';Value=0}; AppsUseLightTheme=@{Kind='DWord';Value=0} }
    $global:SettingsFixture.Registry[$advanced].TaskbarAnimations = @{Kind='DWord';Value=0}
    [Dotfiles.VisualEffects]::Values[0x1002] = $false
    $state = & $visual -Operation Get
    Assert (-not $state.WindowAnimationsDisabled -and -not $state.TransparencyEnabled -and [Dotfiles.VisualEffects]::Writes -eq 0) 'Visual Get must read without applying.'
    & $visual -Operation Set
    Assert (& $visual -Operation Test) 'Disable window animations while explicitly enabling transparency.'
    Assert ([Dotfiles.VisualEffects]::Writes -eq 1 -and [Dotfiles.VisualEffects]::Read(0x1042) -and -not [Dotfiles.VisualEffects]::Read(0x1002)) 'A fresh apply must change only the window animation preference, preserving other on/off choices.'
    $visualWrites = [Dotfiles.VisualEffects]::Writes
    $registryWrites = $global:SettingsFixture.Writes
    & $visual -Operation Set
    Assert ([Dotfiles.VisualEffects]::Writes -eq $visualWrites -and $global:SettingsFixture.Writes -eq $registryWrites) 'Visual reapply must preserve the original journal and avoid writes.'
    Assert ([Dotfiles.VisualEffects]::Read(0x004a) -and $global:SettingsFixture.Registry[$personalize].AppsUseLightTheme.Value -eq 0) 'Preserve font smoothing and theme selection.'
    & $visual -Operation Restore
    $state = & $visual -Operation Get
    Assert (-not $state.WindowAnimationsDisabled -and -not $state.TransparencyEnabled) 'Restore the recorded window animation and transparency preferences.'
    Assert ($global:SettingsFixture.Registry[$advanced].TaskbarAnimations.Value -eq 0) 'Preserve the taskbar preference when no old journal owns it.'
    [Dotfiles.VisualEffects]::Deny = $true
    $caught = $false
    try { & $visual -Operation Set } catch { $caught = $_.Exception.Message -like '*access denied*' }
    Assert $caught 'A failed Windows animation API must not be reported as success.'
    [Dotfiles.VisualEffects]::Deny = $false

    # Upgrade a machine that already applied the earlier broad preset.
    $legacy = @{ ClientArea=0x1042; Menu=0x1002; ComboBox=0x1004; ListBoxSmoothScroll=0x1006; SelectionFade=0x1014; Tooltip=0x1016 }
    $journalPath = Join-Path $scratch 'dotfiles\rollback\visual-effects-user.json'
    $legacyJournal = @{ 'Animation:MinimizeMaximize'=$true }
    foreach ($entry in $legacy.GetEnumerator()) {
        [Dotfiles.VisualEffects]::Values[$entry.Value] = $false
        $legacyJournal['Animation:' + $entry.Key] = ($entry.Key -ne 'Menu')
    }
    $legacyJournal[$advanced + '\TaskbarAnimations'] = @{ Exists=$false; Kind=$null; Value=$null }
    $legacyJournal[$personalize + '\EnableTransparency'] = @{ Exists=$true; Kind='DWord'; Value=0 }
    $legacyJournal | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $journalPath
    [Dotfiles.VisualEffects]::Values[0x0048] = $false
    $global:SettingsFixture.Registry[$personalize].EnableTransparency.Value = 1
    $visualWrites = [Dotfiles.VisualEffects]::Writes
    Assert (-not (& $visual -Operation Test)) 'Legacy records must trigger migration even when the new settings already match.'
    Assert ([Dotfiles.VisualEffects]::Writes -eq $visualWrites) 'Migration Test must remain read-only.'
    & $visual -Operation Set
    Assert (& $visual -Operation Test) 'Migration must restore the broader preferences before reporting success.'
    foreach ($entry in $legacy.GetEnumerator()) {
        Assert ([Dotfiles.VisualEffects]::Read($entry.Value) -eq ($entry.Key -ne 'Menu')) 'Restore saved values rather than turning all other animations on.'
    }
    Assert (-not $global:SettingsFixture.Registry[$advanced].ContainsKey('TaskbarAnimations')) 'Migration must remove a taskbar value that was originally absent.'
    $remainingJournal = Get-Content -LiteralPath $journalPath -Raw | ConvertFrom-Json
    Assert ($remainingJournal.'Animation:MinimizeMaximize' -eq $true -and $remainingJournal.PSObject.Properties.Name.Count -eq 2) 'Keep original window/transparency rollback values and consume legacy records.'
    [Dotfiles.VisualEffects]::Values[0x1042] = $false
    & $visual -Operation Set
    Assert (-not [Dotfiles.VisualEffects]::Read(0x1042)) 'Later user choices outside window animations must remain unmanaged.'
    & $visual -Operation Restore
    Assert ([Dotfiles.VisualEffects]::Read(0x0048) -and $global:SettingsFixture.Registry[$personalize].EnableTransparency.Value -eq 0) 'Restore must retain the original snapshot across migration.'
    Write-Output 'PASS: window-only animations, preserved effects, migration, restoration, idempotence, and denied API writes'

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
    $diagnostics = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
    & $privacy -Operation Set -Context Machine -WarningAction SilentlyContinue
    Assert ($global:SettingsFixture.Registry[$diagnostics].AllowTelemetry.Value -eq 1) 'Pro must retain the minimum supported required diagnostic level.'
    $global:SettingsFixture.Edition = 'Enterprise'
    & $privacy -Operation Set -Context Machine -WarningAction SilentlyContinue
    Assert ($global:SettingsFixture.Registry[$diagnostics].AllowTelemetry.Value -eq 0) 'Enterprise supports diagnostic data off.'
    $global:SettingsFixture.Edition = 'Professional'
    Write-Output 'PASS: edition-aware minimum diagnostic data'
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
