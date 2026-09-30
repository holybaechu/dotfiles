#requires -Version 5.1
# Run with powershell.exe -NoProfile -File .\system\windows\tests\Debloat.Tests.ps1.
# All app inventory and removal commands are replaced with in-memory fixtures.
$ErrorActionPreference = 'Stop'
$global:DotfilesDebloatTest = @{}
$target = Join-Path (Split-Path $PSScriptRoot) 'scripts\Debloat.ps1'

function Assert($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function New-App([string]$Name, [bool]$Bundle = $false, [bool]$Protected = $false) {
    [pscustomobject]@{
        Name = $Name
        PackageFullName = "${Name}_1.0_$Bundle"
        IsBundle = $Bundle
        NonRemovable = $Protected
    }
}

function Reset-Fixture {
    $global:DotfilesDebloatTest.installed = @()
    $global:DotfilesDebloatTest.provisioned = @()
    $global:DotfilesDebloatTest.desktop = @('Daum.PotPlayer')
    $global:DotfilesDebloatTest.calls = New-Object 'System.Collections.Generic.List[string]'
    $global:DotfilesDebloatTest.inventoryError = $false
    $global:DotfilesDebloatTest.listError = $false
    $global:DotfilesDebloatTest.blocked = ''
    $global:DotfilesDebloatTest.falseSuccess = ''
    $global:DotfilesDebloatTest.deprovisionRemovesRegistration = $false
    $global:DotfilesDebloatTest.adminBlocked = $false
}

function Get-AppxPackage {
    [CmdletBinding()]
    param([switch]$AllUsers, [string[]]$PackageTypeFilter)
    Assert $AllUsers 'Appx inventory must cover all users.'
    Assert ('Bundle' -in $PackageTypeFilter -and 'Main' -in $PackageTypeFilter) 'Inventory must include bundles.'
    if ($global:DotfilesDebloatTest.inventoryError) { throw 'Access denied reading app inventory.' }
    $global:DotfilesDebloatTest.installed
}

function Get-AppxProvisionedPackage {
    [CmdletBinding()]
    param([switch]$Online)
    Assert $Online 'Provisioned inventory must target the online image.'
    $global:DotfilesDebloatTest.provisioned
}

function Remove-AppxPackage {
    [CmdletBinding()]
    param([string]$Package, [switch]$AllUsers)
    Assert $AllUsers 'App removal must cover all users.'
    $global:DotfilesDebloatTest.calls.Add("app:$Package")
    $app = $global:DotfilesDebloatTest.installed | Where-Object PackageFullName -eq $Package | Select-Object -First 1
    Assert ($null -ne $app) 'Attempted to remove a stale package.'
    if ($app.Name -eq $global:DotfilesDebloatTest.blocked) { throw 'App removal denied.' }
    $global:DotfilesDebloatTest.installed = @($global:DotfilesDebloatTest.installed | Where-Object Name -ne $app.Name)
}

function Remove-AppxProvisionedPackage {
    [CmdletBinding()]
    param([switch]$Online, [switch]$AllUsers, [string]$PackageName)
    Assert ($Online -and $AllUsers) 'Deprovisioning must cover the online image and all users.'
    $global:DotfilesDebloatTest.calls.Add("provisioned:$PackageName")
    $app = $global:DotfilesDebloatTest.provisioned | Where-Object PackageName -eq $PackageName
    $global:DotfilesDebloatTest.provisioned = @($global:DotfilesDebloatTest.provisioned | Where-Object PackageName -ne $PackageName)
    if ($global:DotfilesDebloatTest.deprovisionRemovesRegistration) {
        $global:DotfilesDebloatTest.installed = @($global:DotfilesDebloatTest.installed | Where-Object Name -ne $app.DisplayName)
    }
}

function winget.exe {
    $id = $args[[Array]::IndexOf($args, '--id') + 1]
    Assert ('--exact' -in $args -and '--source' -in $args -and 'winget' -in $args) 'WinGet must use an exact ID and source.'
    Assert ('--disable-interactivity' -in $args) 'WinGet must not wait for input.'
    $global:LASTEXITCODE = 0
    switch ($args[0]) {
        list {
            if ($global:DotfilesDebloatTest.listError) { $global:LASTEXITCODE = -1978335211 }
            elseif ($id -notin $global:DotfilesDebloatTest.desktop) { $global:LASTEXITCODE = -1978335212 }
        }
        uninstall {
            Assert ('--silent' -in $args) 'Uninstall must be silent.'
            $global:DotfilesDebloatTest.calls.Add("desktop:$id")
            if ($id -eq 'Microsoft.OneDrive' -and $global:DotfilesDebloatTest.adminBlocked) { $global:LASTEXITCODE = -1978335107 }
            elseif ($id -eq $global:DotfilesDebloatTest.blocked) { $global:LASTEXITCODE = 5 }
            elseif ($id -ne $global:DotfilesDebloatTest.falseSuccess) { $global:DotfilesDebloatTest.desktop = @($global:DotfilesDebloatTest.desktop | Where-Object { $_ -ne $id }) }
        }
        default { throw "Unexpected WinGet action: $($args[0])" }
    }
}

function Assert-Failure([string]$Message, [string]$AppType = 'Store') {
    $caught = $null
    try { & $target -Operation Set -AppType $AppType } catch { $caught = $_.Exception.Message }
    Assert ($caught -like "*$Message*") "Expected failure containing '$Message'; got '$caught'."
}

Reset-Fixture
$global:DotfilesDebloatTest.installed = @(
    (New-App 'Microsoft.BingSearch')
    (New-App 'Microsoft.ZuneMusic')
    (New-App 'Microsoft.StartExperiencesApp' $true)
    (New-App 'Microsoft.StartExperiencesApp')
    (New-App 'Microsoft.Windows.StartMenuExperienceHost' $false $true)
    (New-App 'Microsoft.WindowsStore')
    (New-App 'Microsoft.DesktopAppInstaller')
    (New-App 'Microsoft.XboxGameCallableUI' $false $true)
    (New-App 'Microsoft.HEVCVideoExtension')
)
$global:DotfilesDebloatTest.provisioned = @(
    [pscustomobject]@{ DisplayName = 'Microsoft.BingSearch'; PackageName = 'Bing_provisioned' }
    [pscustomobject]@{ DisplayName = 'Microsoft.WindowsStore'; PackageName = 'Store_provisioned' }
)
$global:DotfilesDebloatTest.desktop += @('Microsoft.Edge', 'Microsoft.OneDrive', 'Microsoft.EdgeWebView2Runtime', 'Microsoft.Edge.Beta')
$before = & $target -Operation Get -AppType Store
Assert ($before.Installed.Count -eq 4 -and $before.Desktop.Count -eq 0) 'Store inventory must not include desktop apps.'
$beforeDesktop = & $target -Operation Get -AppType Desktop
Assert ($beforeDesktop.Installed.Count -eq 0 -and $beforeDesktop.Provisioned.Count -eq 0 -and $beforeDesktop.Desktop.Count -eq 2) 'Desktop inventory must not include Store apps.'
Assert (-not (& $target -Operation Test -AppType Store)) 'Test must detect unwanted apps.'
Assert ($global:DotfilesDebloatTest.calls.Count -eq 0) 'Get and Test must not remove apps.'
& $target -Operation Set -AppType Store
& $target -Operation Set -AppType Desktop
Assert (& $target -Operation Test -AppType Store) 'Set must converge to the desired state.'
Assert (& $target -Operation Test -AppType Desktop) 'Desktop Set must converge to the desired state.'
Assert ($global:DotfilesDebloatTest.installed.Count -eq 5 -and $global:DotfilesDebloatTest.provisioned.Count -eq 1) 'Unrelated apps must survive.'
Assert ('Microsoft.EdgeWebView2Runtime' -in $global:DotfilesDebloatTest.desktop -and 'Microsoft.Edge.Beta' -in $global:DotfilesDebloatTest.desktop) 'Exact Edge targeting must preserve shared runtime and other channels.'
Assert (@($global:DotfilesDebloatTest.calls | Where-Object { $_ -like 'app:Microsoft.StartExperiencesApp*' }).Count -eq 1) 'Remove a bundle once, via its parent.'
$count = $global:DotfilesDebloatTest.calls.Count
& $target -Operation Set -AppType Store
& $target -Operation Set -AppType Desktop
Assert ($global:DotfilesDebloatTest.calls.Count -eq $count) 'A rerun must not repeat removals.'
Write-Output 'PASS: read-only inventory, exact targeting, bundles, deprovisioning, and reruns'

Reset-Fixture
$global:DotfilesDebloatTest.provisioned = @([pscustomobject]@{ DisplayName = 'Microsoft.ZuneMusic'; PackageName = 'Media_provisioned' })
$global:DotfilesDebloatTest.desktop = @('Microsoft.OneDrive')
Assert-Failure 'Install PotPlayer first'
Assert ($global:DotfilesDebloatTest.calls.Count -eq 0) 'Missing PotPlayer must block removal before any mutation.'
Write-Output 'PASS: replacement is required even for provisioned-only Media Player'

Reset-Fixture
$global:DotfilesDebloatTest.inventoryError = $true
Assert-Failure 'Access denied'
Assert ($global:DotfilesDebloatTest.calls.Count -eq 0) 'An inventory failure must not be treated as absence.'
$global:DotfilesDebloatTest.inventoryError = $false
$global:DotfilesDebloatTest.listError = $true
Assert-Failure 'Checking Microsoft.OneDrive failed' 'Desktop'
Assert ($global:DotfilesDebloatTest.calls.Count -eq 0) 'A WinGet source failure must not trigger removals.'
Write-Output 'PASS: denied inventory and WinGet source failures stop before removal'

Reset-Fixture
$global:DotfilesDebloatTest.installed = @((New-App 'Microsoft.Todos'), (New-App 'Microsoft.BingNews'))
$global:DotfilesDebloatTest.blocked = 'Microsoft.Todos'
$global:DotfilesDebloatTest.desktop += 'Microsoft.OneDrive'
Assert-Failure 'App removal denied'
& $target -Operation Set -AppType Desktop
Assert ($global:DotfilesDebloatTest.installed.Count -eq 1 -and 'Microsoft.OneDrive' -notin $global:DotfilesDebloatTest.desktop) 'Other requested removals must continue after one failure.'
Write-Output 'PASS: failed removals are reported after attempting other apps'

Reset-Fixture
$global:DotfilesDebloatTest.desktop += 'Microsoft.Edge'
$global:DotfilesDebloatTest.falseSuccess = 'Microsoft.Edge'
Assert-Failure 'Windows may restrict Edge removal' 'Desktop'
Write-Output 'PASS: a successful exit code cannot hide an Edge uninstall that did nothing'

Reset-Fixture
$global:DotfilesDebloatTest.installed = @((New-App 'Microsoft.BingSearch' $false $true))
Assert-Failure 'non-removable'
Assert ($global:DotfilesDebloatTest.calls.Count -eq 0) 'Protected apps must not be forcibly removed.'
Write-Output 'PASS: protected-package failures remain visible'

Reset-Fixture
$global:DotfilesDebloatTest.installed = @((New-App 'Microsoft.BingSearch'))
$global:DotfilesDebloatTest.provisioned = @([pscustomobject]@{ DisplayName = 'Microsoft.BingSearch'; PackageName = 'Bing_provisioned' })
$global:DotfilesDebloatTest.deprovisionRemovesRegistration = $true
& $target -Operation Set -AppType Store
Assert ($global:DotfilesDebloatTest.calls.Count -eq 1) 'Refresh registrations after deprovisioning.'
Write-Output 'PASS: deprovisioning cannot cause a second removal of stale registrations'

Reset-Fixture
$global:DotfilesDebloatTest.inventoryError = $true
$global:DotfilesDebloatTest.desktop += 'Microsoft.OneDrive'
& $target -Operation Set -AppType Desktop
Assert ('Microsoft.OneDrive' -notin $global:DotfilesDebloatTest.desktop) 'Desktop removal must work without permission to query all-user Store apps.'
Write-Output 'PASS: user-scope OneDrive removal never queries administrator-only Appx inventory'

Reset-Fixture
$global:DotfilesDebloatTest.listError = $true
$global:DotfilesDebloatTest.installed = @((New-App 'Microsoft.BingSearch'))
& $target -Operation Set -AppType Store
Assert ($global:DotfilesDebloatTest.installed.Count -eq 0) 'Store removal must not query desktop apps through WinGet.'
Write-Output 'PASS: elevated Store removal never runs desktop WinGet inventory or uninstall'

Reset-Fixture
$global:DotfilesDebloatTest.desktop += 'Microsoft.OneDrive'
$global:DotfilesDebloatTest.adminBlocked = $true
Assert-Failure 'normal, non-administrator PowerShell window' 'Desktop'
Write-Output 'PASS: an elevated user-scope uninstall reports the correct recovery instruction'

$caught = $null
try { & $target -Operation Set } catch { $caught = $_.Exception.Message }
Assert ($caught -like '*Direct calls must specify*') 'Reject ambiguous direct calls instead of silently skipping one app type.'
Write-Output 'PASS: direct calls require an explicit app type'

Reset-Fixture
$global:DotfilesDebloatTest.installed = @(
    (New-App 'Microsoft.WidgetsPlatformRuntime')
    (New-App 'Microsoft.MicrosoftOfficeHub')
    (New-App 'Microsoft.YourPhone')
    (New-App 'MicrosoftWindows.CrossDevice')
    (New-App 'Microsoft.Office.Word')
)
& $target -Operation Set -AppType Store
Assert ($global:DotfilesDebloatTest.installed.Count -eq 3 -and 'Microsoft.Office.Word' -in $global:DotfilesDebloatTest.installed.Name -and 'Microsoft.YourPhone' -in $global:DotfilesDebloatTest.installed.Name -and 'MicrosoftWindows.CrossDevice' -in $global:DotfilesDebloatTest.installed.Name) 'Remove selected Widgets/Office launcher packages while preserving phone integration and actual Office apps.'
Write-Output 'PASS: additional removals preserve phone integration and actual Office applications'
