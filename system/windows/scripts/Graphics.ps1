#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Get', 'Test', 'Set', 'Restore')][string]$Operation = 'Test',
    [Parameter(Mandatory)][ValidateSet('User', 'Machine')][string]$Context
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\RegistryState.ps1"
$build = [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild

function Set-SwapEffectToken([string]$Value, [string]$Token) {
    $tokens = @($Value -split ';' | Where-Object { $_ -and $_ -notmatch '^SwapEffectUpgradeEnable=' })
    if ($Token) { $tokens += $Token }
    if ($tokens.Count) { ($tokens -join ';') + ';' } else { '' }
}

function Get-HardwareScheduling {
    $path = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-dxdiag-' + [guid]::NewGuid().ToString('N') + '.xml')
    $process = $null
    try {
        $process = Start-Process -FilePath "$env:WINDIR\System32\dxdiag.exe" -ArgumentList '/whql:off', '/x', ('"' + $path + '"') -WindowStyle Hidden -PassThru
        if (-not $process.WaitForExit(30000)) { $process.Kill(); throw 'Graphics capability inventory timed out.' }
        if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $path)) { throw 'DxDiag did not produce a capability report.' }
        [xml]$report = Get-Content -LiteralPath $path -Raw
        $devices = @($report.DxDiag.DisplayDevices.DisplayDevice | ForEach-Object {
            [pscustomobject]@{
                Name = $_.CardName
                Supported = $_.HardwareSchedulingAttributes -match 'DriverSupportState:Stable\b'
                Enabled = $_.HardwareSchedulingAttributes -match 'Enabled:True\b'
            }
        })
        if (-not $devices.Count) { throw 'DxDiag reported no display devices.' }
        $capable = @($devices | Where-Object Supported)
        @{ Supported = $capable.Count -gt 0; Enabled = $capable.Count -gt 0 -and @($capable | Where-Object { -not $_.Enabled }).Count -eq 0; Devices = $devices }
    } finally {
        if ($process) { $process.Dispose() }
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
}

if ($Context -eq 'User') {
    if ($build -lt 22621) { throw 'Windowed-game optimizations require Windows 11 22H2 or later.' }
    $journalPath = Join-Path $env:LOCALAPPDATA 'dotfiles\rollback\graphics-user.json'
    $setting = @{ Path = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'; Name = 'DirectXUserGlobalSettings'; Kind = 'String' }
    $actual = Get-RegistryState $setting
    $setting.Value = Set-SwapEffectToken $actual.Value 'SwapEffectUpgradeEnable=1'
    switch ($Operation) {
        Get { @{ WindowedGamesEnabled = $actual.Value -match '(^|;)SwapEffectUpgradeEnable=1(;|$)'; VariableRefreshRate = 'Unchanged' } }
        Test { Test-RegistrySetting $setting }
        Set { Set-TrackedRegistryValue $setting $journalPath }
        Restore {
            # Restore only our token; never overwrite later HDR/VRR preferences.
            $journal = Read-RegistryJournal $journalPath
            $id = $setting.Path + '\' + $setting.Name
            if ($journal.ContainsKey($id)) {
                $previous = $journal[$id]
                $token = @($previous.Value -split ';' | Where-Object { $_ -match '^SwapEffectUpgradeEnable=' }) | Select-Object -Last 1
                $restored = Set-SwapEffectToken $actual.Value $token
                if (-not $previous.Exists -and -not $restored) {
                    if ($actual.Exists) { Remove-ItemProperty -LiteralPath $setting.Path -Name $setting.Name }
                } else {
                    [void](New-ItemProperty -LiteralPath $setting.Path -Name $setting.Name -Value $restored -PropertyType String -Force)
                }
                if ((Get-RegistryState $setting).Value -cne $(if (-not $previous.Exists -and -not $restored) { $null } else { $restored })) { throw 'Graphics restore verification failed.' }
                $journal.Remove($id)
                Save-RegistryJournal $journalPath $journal
            }
        }
    }
} else {
    $journalPath = Join-Path $env:ProgramData 'dotfiles\rollback\graphics-machine.json'
    $setting = @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'; Name = 'HwSchMode'; Kind = 'DWord'; Value = 2 }
    if ($Operation -eq 'Restore') { Restore-RegistryValues @($setting) $journalPath; Write-Warning 'Restart Windows to complete graphics restoration.'; return }
    $hardware = Get-HardwareScheduling
    $actual = Get-RegistryState $setting
    $status = if (-not $hardware.Supported) { 'Unsupported' }
        elseif ($hardware.Enabled -and $actual.Value -ne 1) { 'Enabled' }
        elseif ($actual.Value -eq 2) { 'RestartPending' }
        else { 'Disabled' }
    switch ($Operation) {
        Get { @{ Status = $status; Devices = $hardware.Devices } }
        Test {
            if ($status -eq 'RestartPending') { Write-Warning 'GPU scheduling is configured but not active. Restart and check Graphics.ps1 -Operation Get -Context Machine.' }
            $status -in @('Enabled', 'RestartPending')
        }
        Set {
            if ($status -eq 'Unsupported') { throw 'GPU scheduling support could not be confirmed from DxDiag. No setting was changed.' }
            if ($status -eq 'Enabled') { return }
            Set-TrackedRegistryValue $setting $journalPath
            Write-Warning 'GPU scheduling is configured, not yet verified active. Restart Windows and rerun the graphics check.'
        }
    }
}
