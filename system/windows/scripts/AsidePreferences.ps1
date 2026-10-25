#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Get', 'Test', 'Set')][string]$Operation = 'Test'
)
$ErrorActionPreference = 'Stop'

# Native file formats verified with Aside 1.0.1022.1 / runtime 1.26.1024.24.
# Aside defaults plus https://github.com/yokoffing/filterlists#enhanced.
function Read-AsideJson([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return @{} }
    $data = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
    if ($data -isnot [System.Collections.IDictionary]) { throw "Expected a JSON object in $Path." }
    return $data
}

$userData = Join-Path $env:LOCALAPPDATA 'Aside\User Data'
$accountsPath = Join-Path $env:USERPROFILE '.aside\password-manager\accounts'
$profiles = @(if (Test-Path -LiteralPath $userData) {
    Get-ChildItem -LiteralPath $userData -Directory | Where-Object {
        Test-Path -LiteralPath (Join-Path $_.FullName 'Preferences')
    }
})
$accounts = @(if (Test-Path -LiteralPath $accountsPath) {
    Get-ChildItem -LiteralPath $accountsPath -Directory
})
$filters = Get-Content -LiteralPath "$PSScriptRoot\..\resources\aside-filters.json" -Raw | ConvertFrom-Json -AsHashtable
$changes = @(
    foreach ($account in $accounts) {
        $path = Join-Path $account.FullName 'settings.json'
        $settings = Read-AsideJson $path
        if ($settings.useBuiltinPasswordManager -cne $false) {
            $settings.useBuiltinPasswordManager = $false
            $settings.updatedAt = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            @{ Path = $path; Data = $settings }
        }
    }
    foreach ($profile in $profiles) {
        $path = Join-Path $profile.FullName 'AsideAdBlock\subscriptions.json'
        $state = Read-AsideJson $path
        $changed = $state.enabled -cne $true
        $state.enabled = $true
        $subscriptions = @($state.subscriptions | Where-Object { $null -ne $_ })
        foreach ($filter in $filters) {
            $matches = @($subscriptions | Where-Object { $_.url -ceq $filter.url -or $filter.aliases -ccontains $_.url })
            if (-not $matches.Count) {
                $subscriptions += @{
                    id = [guid]::NewGuid().ToString('N')
                    name = $filter.name
                    url = $filter.url
                    enabled = $true
                }
                $changed = $true
            } else {
                foreach ($subscription in $matches) {
                    if ($subscription.url -cne $filter.url) {
                        $subscription.url = $filter.url
                        $subscription.etag = ''
                        $subscription.lastModifiedHeader = ''
                        $subscription.nextUpdateMs = 0
                        $changed = $true
                    }
                    if ($subscription.enabled -cne $true) {
                        $subscription.enabled = $true
                        $changed = $true
                    }
                }
            }
        }
        if ($subscriptions.Count -gt 64) { throw 'Aside supports at most 64 filter subscriptions. Remove unused filters before reapplying.' }
        $state.subscriptions = $subscriptions
        if ($changed) { @{ Path = $path; Data = $state } }
    }
)
$initialized = $profiles.Count -gt 0 -and $accounts.Count -gt 0
if ($Operation -eq 'Get') {
    return @{ Initialized = $initialized; Profiles = $profiles.Count; PasswordAccounts = $accounts.Count; PendingFiles = @($changes | ForEach-Object { $_.Path }) }
}
if ($Operation -eq 'Test') { return $initialized -and $changes.Count -eq 0 }
if (-not $initialized) { throw 'Launch Aside and sign in once, then quit Aside and rerun the preferences module.' }
if (-not $changes.Count) { return }
if (Get-Process -Name Aside, aside-daemon -ErrorAction SilentlyContinue) {
    throw 'Quit Aside (including its background daemon), then rerun the preferences module so it cannot overwrite these settings.'
}

foreach ($change in $changes) {
    [void][IO.Directory]::CreateDirectory((Split-Path $change.Path))
    $change.Data | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $change.Path -Encoding utf8NoBOM
}
if (-not (& $PSCommandPath -Operation Test)) { throw 'Aside did not retain the requested password-manager and adblock settings.' }
