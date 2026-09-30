#requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateSet('Get', 'Test', 'Set')][string]$Operation = 'Test',
    [ValidateSet('Store', 'Desktop')][string]$AppType
)

$ErrorActionPreference = 'Stop'
if (-not $AppType) {
    throw 'Run Configure.ps1 -Action Apply -Module debloat from a normal PowerShell window. Direct calls must specify -AppType Store (administrator) or -AppType Desktop (normal user).'
}
# Appx needs Windows PowerShell; debloat.winget uses WindowsPowerShellScript.
if ($AppType -eq 'Store' -and $PSVersionTable.PSEdition -ne 'Desktop') {
    throw 'Run debloating through Configure.ps1 -Module debloat, or Windows PowerShell 5.1.'
}

# Exact identities only. In particular, StartExperiencesApp is not StartMenuExperienceHost.
$appNames = @(
    'MicrosoftCorporationII.MicrosoftFamily'
    'Microsoft.BingSearch'
    'Clipchamp.Clipchamp'
    'MicrosoftTeams'
    'MSTeams'
    'Microsoft.Todos'
    'Microsoft.OutlookForWindows'
    'Microsoft.PowerAutomateDesktop'
    'Microsoft.StartExperiencesApp'
    'Microsoft.WindowsSoundRecorder'
    'Microsoft.GamingApp'
    'Microsoft.XboxApp'
    'Microsoft.Xbox.TCUI'
    'Microsoft.XboxGameOverlay'
    'Microsoft.XboxGamingOverlay'
    'Microsoft.XboxIdentityProvider'
    'Microsoft.XboxSpeechToTextOverlay'
    'Microsoft.BingWeather'
    'Microsoft.BingNews'
    'Microsoft.ZuneMusic'
    'MicrosoftCorporationII.QuickAssist'
    'Microsoft.MicrosoftStickyNotes'
    'Microsoft.WindowsFeedbackHub'
)
$desktopIds = @(
    'Microsoft.OneDrive'
    'Microsoft.Teams.Classic'
    'Microsoft.PowerAutomateDesktop'
    'Microsoft.Edge'
)

function Test-WinGetPackage([string]$Id) {
    $output = & winget.exe list --id $Id --exact --source winget --accept-source-agreements --disable-interactivity 2>&1
    $code = $LASTEXITCODE
    if ($code -eq 0) { return $true }
    # APPINSTALLER_CLI_ERROR_NO_APPLICATIONS_FOUND; all other errors are failures.
    if ($code -eq -1978335212) { return $false }
    throw "Checking $Id failed with WinGet exit code ${code}: $($output -join ' ')"
}

function Get-DebloatState {
    $installed = @()
    $provisioned = @()
    $desktop = @()
    if ($AppType -eq 'Store') {
        $installed = @(Get-AppxPackage -AllUsers -PackageTypeFilter Main, Bundle -ErrorAction Stop |
            Where-Object { $_.Name -in $appNames })
        $provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop |
            Where-Object { $_.DisplayName -in $appNames })
    } else {
        $desktop = @($desktopIds | Where-Object { Test-WinGetPackage $_ })
    }
    [pscustomobject]@{
        Installed = $installed
        Provisioned = $provisioned
        Desktop = $desktop
    }
}

$state = Get-DebloatState
switch ($Operation) {
    Get {
        [pscustomobject]@{
            Installed = @($state.Installed | Select-Object -ExpandProperty PackageFullName)
            Provisioned = @($state.Provisioned | Select-Object -ExpandProperty PackageName)
            Desktop = @($state.Desktop)
        }
    }
    Test {
        ($state.Installed.Count + $state.Provisioned.Count + $state.Desktop.Count) -eq 0
    }
    Set {
        # Keep a working replacement even when this module is applied on its own.
        if (('Microsoft.ZuneMusic' -in $state.Installed.Name -or
                'Microsoft.ZuneMusic' -in $state.Provisioned.DisplayName) -and
                -not (Test-WinGetPackage 'Daum.PotPlayer')) {
            throw 'Install PotPlayer first: run Configure.ps1 -Action Apply -Module packages.'
        }

        $failures = New-Object 'System.Collections.Generic.List[string]'
        # Remove provisioning first so newly created accounts do not receive these apps.
        foreach ($package in $state.Provisioned) {
            try {
                Remove-AppxProvisionedPackage -Online -AllUsers -PackageName $package.PackageName -ErrorAction Stop | Out-Null
            } catch {
                $failures.Add("Provisioned $($package.DisplayName): $($_.Exception.Message)")
            }
        }

        # Deprovisioning can also remove registrations; do not act on stale identities.
        if ($AppType -eq 'Store') {
            $state.Installed = @(Get-AppxPackage -AllUsers -PackageTypeFilter Main, Bundle -ErrorAction Stop |
                Where-Object { $_.Name -in $appNames })
        }
        # Remove bundles via their parent identity, not their constituent main packages.
        $bundleNames = @($state.Installed | Where-Object IsBundle | Select-Object -ExpandProperty Name)
        $packages = @($state.Installed | Where-Object { $_.IsBundle -or $_.Name -notin $bundleNames } |
            Sort-Object -Property PackageFullName -Unique)
        foreach ($package in $packages) {
            try {
                if ($package.NonRemovable) { throw 'Windows marks this package as non-removable.' }
                Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop
            } catch {
                $failures.Add("$($package.Name): $($_.Exception.Message)")
            }
        }

        foreach ($id in $state.Desktop) {
            try {
                $output = & winget.exe uninstall --id $id --exact --source winget --silent --accept-source-agreements --disable-interactivity 2>&1
                $code = $LASTEXITCODE
                if ($code -eq -1978335107) {
                    throw 'This user-scope app must be uninstalled from a normal, non-administrator PowerShell window. Run Configure.ps1 -Action Apply -Module debloat there.'
                }
                # The Store-app resource may already have removed the WinGet match.
                if ($code -notin @(0, -1978335212)) {
                    throw "WinGet exit code ${code}: $($output -join ' ')"
                }
            } catch {
                $failures.Add("${id}: $($_.Exception.Message)")
            }
        }

        # Some uninstallers return success without removing the app (notably protected Edge).
        $remaining = Get-DebloatState
        $names = @($remaining.Installed.Name) + @($remaining.Provisioned.DisplayName) + @($remaining.Desktop)
        $names = @($names | Where-Object { $_ } | Sort-Object -Unique)
        if ($names.Count) { $failures.Add("Still installed or provisioned: $($names -join ', ').") }
        if ('Microsoft.Edge' -in $state.Desktop -and ('Microsoft.Edge' -in $remaining.Desktop)) {
            $failures.Add('Windows may restrict Edge removal on this device/region. WebView2 and the Edge updater are deliberately retained.')
        }
        if ($failures.Count) {
            throw "Debloating did not complete. Close the affected apps, resolve any uninstall or restart requirement, and rerun. $($failures -join ' ')"
        }
    }
}
