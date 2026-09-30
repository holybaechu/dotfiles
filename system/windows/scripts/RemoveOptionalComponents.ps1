#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('Get', 'Test', 'Set')][string]$Operation = 'Test')
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Windows PowerShell 5.1 for optional-component servicing.' }
. "$PSScriptRoot\RegistryState.ps1"
$recallSetting = @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name='AllowRecallEnablement'; Kind='DWord'; Value=0 }
$version = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$recallPolicyAvailable = [int]$version.CurrentBuild -gt 26100 -or ([int]$version.CurrentBuild -eq 26100 -and [int]$version.UBR -ge 3915)

function Get-ComponentState {
    $features = @(Get-WindowsOptionalFeature -Online -ErrorAction Stop | Where-Object {
        $_.FeatureName -in @('Recall', 'WindowsMediaPlayer', 'FaxServicesClientPackage', 'ClickToDo')
    } | ForEach-Object { [pscustomobject]@{ FeatureName = $_.FeatureName; State = $_.State.ToString() } })
    $capabilities = @(Get-WindowsCapability -Online -ErrorAction Stop | Where-Object {
        $_.Name -match '^(Media\.WindowsMediaPlayer|Print\.Fax\.Scan)~~~~[0-9.]+$' -or
        $_.Name -match '^Language\.Handwriting~~~[a-zA-Z0-9-]+~[0-9.]+$'
    } | ForEach-Object { [pscustomobject]@{ Name = $_.Name; State = $_.State.ToString() } })
    $unsupported = @()
    foreach ($feature in $features | Where-Object { $_.State -eq 'Disabled' }) {
        $unsupported += "$($feature.FeatureName) is disabled, but full payload removal is not verified. Windows client servicing can retain payloads; it is not counted as removed."
    }
    if ('Recall' -notin $features.FeatureName -and @(Get-AppxPackage -AllUsers -Name MicrosoftWindows.Client.AIX -ErrorAction Stop).Count) {
        $unsupported += 'Recall removal cannot be confirmed: no Recall optional feature is exposed, but the shared AIX package remains. It is not deleted manually.'
    }
    if ('ClickToDo' -notin $features.FeatureName -and @(Get-AppxPackage -AllUsers -Name MicrosoftWindows.Client.CoreAI -ErrorAction Stop).Count) {
        $unsupported += 'Click to Do remains installed: CoreAI is a protected shared package and no standalone optional feature is exposed. No supported removal was identified.'
    }
    [pscustomobject]@{ Features = $features; Capabilities = $capabilities; Unsupported = $unsupported
        RecallPolicySupported = $recallPolicyAvailable -and 'Recall' -in $features.FeatureName
        RecallPolicyConfigured = [bool](Test-RegistrySetting $recallSetting) }
}

function Get-RemainingComponents($State) {
    # Disabled-only payload retention is reported as unsupported, not retried forever.
    @($State.Features | Where-Object { $_.State -notin @('DisabledWithPayloadRemoved','Disabled') } | ForEach-Object { $_.FeatureName })
    @($State.Capabilities | Where-Object { $_.State -ne 'NotPresent' } | ForEach-Object { $_.Name })
    if ($State.RecallPolicySupported -and -not $State.RecallPolicyConfigured) { 'Recall removal policy' }
}

$state = Get-ComponentState
foreach ($message in $state.Unsupported) { Write-Warning $message }
switch ($Operation) {
    Get { $state }
    Test { @(Get-RemainingComponents $state).Count -eq 0 }
    Set {
        if (-not @(Get-RemainingComponents $state).Count) { return }
        if (@($state.Features | Where-Object { $_.FeatureName -eq 'WindowsMediaPlayer' -and $_.State -eq 'Enabled' }).Count -or
            @($state.Capabilities | Where-Object { $_.Name -like 'Media.WindowsMediaPlayer~*' -and $_.State -eq 'Installed' }).Count) {
            $null = & winget.exe list --id Daum.PotPlayer --exact --source winget --accept-source-agreements --disable-interactivity
            if ($LASTEXITCODE -ne 0) { throw 'PotPlayer could not be verified. Apply the packages module before removing legacy Media Player.' }
        }
        $backup = Join-Path $env:ProgramData 'dotfiles\rollback\components.json'
        $original = if (Test-Path -LiteralPath $backup) { Get-Content -LiteralPath $backup -Raw | ConvertFrom-Json } else { [pscustomobject]@{ Features=@(); Capabilities=@() } }
        foreach ($feature in $state.Features) { if ($feature.FeatureName -notin $original.Features.FeatureName) { $original.Features += $feature } }
        foreach ($capability in $state.Capabilities) { if ($capability.Name -notin $original.Capabilities.Name) { $original.Capabilities += $capability } }
        [void](New-Item -ItemType Directory -Path (Split-Path $backup) -Force)
        $temporary = $backup + '.' + [guid]::NewGuid().ToString('N')
        try { $original | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $temporary -Encoding UTF8; Move-Item -LiteralPath $temporary -Destination $backup -Force }
        finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force } }
        $restart = $false
        if ($state.RecallPolicySupported -and -not $state.RecallPolicyConfigured) {
            Set-TrackedRegistryValue $recallSetting (Join-Path $env:ProgramData 'dotfiles\rollback\components-registry.json')
            $restart = $true
        }
        $failures = New-Object 'System.Collections.Generic.List[string]'
        foreach ($capability in $state.Capabilities | Where-Object { $_.State -ne 'NotPresent' }) {
            try {
                if ($capability.State -match 'Pending') { $restart = $true; continue }
                $result = Remove-WindowsCapability -Online -Name $capability.Name -NoRestart -ErrorAction Stop
                $restart = $restart -or $result.RestartNeeded
            } catch { $failures.Add("$($capability.Name): $($_.Exception.Message)") }
        }
        # Refresh because removing a capability can also remove its optional feature.
        $refreshed = Get-ComponentState
        foreach ($feature in $refreshed.Features | Where-Object { $_.State -notin @('DisabledWithPayloadRemoved','Disabled') }) {
            try {
                if ($feature.State -match 'Pending') { $restart = $true; continue }
                $result = Disable-WindowsOptionalFeature -Online -FeatureName $feature.FeatureName -Remove -NoRestart -ErrorAction Stop
                $restart = $restart -or $result.RestartNeeded
            } catch { $failures.Add("$($feature.FeatureName): $($_.Exception.Message)") }
        }
        $remaining = Get-ComponentState
        if (@($remaining.Features + $remaining.Capabilities | Where-Object { $_.State -match 'Pending' }).Count) { $restart = $true }
        $names = @(Get-RemainingComponents $remaining)
        if ($restart) { Write-Warning "Restart required; component removal is not yet complete. Recheck after restart. Remaining: $($names -join ', ')." }
        elseif ($names.Count) { $failures.Add("Not removed (disabling alone is incomplete): $($names -join ', ').") }
        if ($failures.Count) { throw ($failures -join ' ') }
        foreach ($message in $remaining.Unsupported) { Write-Warning $message }
    }
}
