#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Repository = 'https://github.com/holybaechu/dotfiles.git',
    [ValidatePattern('^[a-z_][a-z0-9_-]{0,31}$')]
    [string]$LinuxUser = 'holybaechu'
)

$ErrorActionPreference = 'Stop'
if ($LinuxUser -eq 'root') { throw 'Choose a non-root Linux user.' }

function Assert-WslSuccess {
    param([string]$Operation)
    # A pending Windows update does not mean a working WSL needs a restart.
    if ($LASTEXITCODE -in @(3010, 1641)) {
        Write-Host 'Arch Linux setup is waiting for a Windows restart.'
        Write-Host 'Restart Windows, then rerun system\wsl\Setup.ps1 with the same arguments, or rerun bootstrap.ps1.'
        exit 3010
    }
    if ($LASTEXITCODE -ne 0) {
        throw "$Operation failed with exit code $LASTEXITCODE. Resolve the WSL error above, then rerun bootstrap.ps1."
    }
}

# Install the platform without also installing Ubuntu. WSL may request elevation.
wsl.exe --install --no-distribution --web-download
Assert-WslSuccess 'Installing WSL'
wsl.exe --set-default-version 2
Assert-WslSuccess 'Selecting WSL2'

# Read registration without depending on localized `wsl --list` output.
$registrations = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss'
$arch = @(if (Test-Path -LiteralPath $registrations) {
    Get-ChildItem -LiteralPath $registrations | Get-ItemProperty |
        Where-Object { $_.DistributionName -eq 'archlinux' }
})
if (-not $arch.Count) {
    wsl.exe --install --distribution archlinux --no-launch --web-download
    Assert-WslSuccess 'Installing Arch Linux'
}
elseif ($arch[0].Version -ne 2) {
    wsl.exe --set-version archlinux 2
    Assert-WslSuccess 'Selecting WSL2 for Arch Linux'
}

$provisionScript = Join-Path $PSScriptRoot 'provision.sh'
$linuxScript = wsl.exe --distribution archlinux --user root --exec wslpath -a -u $provisionScript
Assert-WslSuccess 'Locating the Arch provisioning script'
$linuxScript = ($linuxScript -join "`n").Trim()
if (-not $linuxScript.StartsWith('/')) { throw 'WSL did not return an absolute Linux script path.' }
wsl.exe --distribution archlinux --user root --exec bash $linuxScript $LinuxUser $Repository
Assert-WslSuccess 'Provisioning Arch Linux and applying Linux dotfiles'

wsl.exe --manage archlinux --set-default-user $LinuxUser
Assert-WslSuccess 'Selecting the default Arch user'
wsl.exe --set-default archlinux
Assert-WslSuccess 'Selecting the default WSL distribution'
Write-Host "Arch Linux is ready on WSL2 as $LinuxUser. Alt+Enter will open it in Windows Terminal."
