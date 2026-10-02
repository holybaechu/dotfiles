[CmdletBinding()]
param(
    [string]$Repository = 'https://github.com/holybaechu/dotfiles.git',
    [ValidatePattern('^[a-z_][a-z0-9_-]{0,31}$')]
    [string]$WslUser = 'holybaechu'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command winget.exe -CommandType Application -ErrorAction SilentlyContinue)) {
    throw 'WinGet is required. Install or update App Installer from Microsoft Store, then rerun bootstrap.ps1.'
}
$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run bootstrap.ps1 from a normal PowerShell window as your own user. Setup requests elevation for machine changes.'
}
if ($WslUser -eq 'root') { throw 'Choose a non-root WSL user.' }

function Update-SessionPath {
    $paths = @(
        $env:PATH
        [Environment]::GetEnvironmentVariable('PATH', 'Machine')
        [Environment]::GetEnvironmentVariable('PATH', 'User')
    )
    $env:PATH = ([Environment]::ExpandEnvironmentVariables($paths -join ';').Split(';') |
        Where-Object { $_ } | Select-Object -Unique) -join ';'
}

Update-SessionPath
if ($PSVersionTable.PSVersion.Major -lt 7) {
    # Windows PowerShell is the entry point on a fresh Windows installation.
    if (-not (Get-Command pwsh.exe -CommandType Application -ErrorAction SilentlyContinue)) {
        winget.exe install --id Microsoft.PowerShell --exact --source winget --accept-source-agreements --accept-package-agreements --disable-interactivity
        if ($LASTEXITCODE -ne 0) {
            throw "Installing PowerShell 7 failed with exit code $LASTEXITCODE."
        }
        Update-SessionPath
    }
    $powerShell = Get-Command pwsh.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1 -ExpandProperty Source
    if ($PSCommandPath) {
        & $powerShell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -Repository $Repository -WslUser $WslUser
        exit $LASTEXITCODE
    }
    # Pass the script in memory so web bootstrap does not need a local file.
    $repositoryArgument = $Repository.Replace("'", "''")
    $command = "& {`n$($MyInvocation.MyCommand.ScriptBlock.ToString())`n} -Repository '$repositoryArgument' -WslUser '$WslUser'"
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    & $powerShell -NoLogo -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedCommand
    exit $LASTEXITCODE
}

try {
    $step = 'Install chezmoi'
    Write-Host "==> $step"
    if (-not (Get-Command chezmoi.exe -ErrorAction SilentlyContinue)) {
        winget.exe install --id twpayne.chezmoi --exact --source winget --accept-source-agreements --accept-package-agreements --disable-interactivity
        if ($LASTEXITCODE -ne 0) {
            throw "Installing chezmoi failed with exit code $LASTEXITCODE."
        }
        Update-SessionPath
    }

    $step = 'Initialize the dotfiles checkout'
    Write-Host "==> $step"
    # A local invocation uses this checkout, including uncommitted edits. Web setup
    # uses chezmoi's configured source directory and preserves an existing checkout.
    $chezmoiArguments = @()
    if ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot '.chezmoiroot'))) {
        $chezmoiArguments = @('--source', $PSScriptRoot)
    }
    chezmoi.exe @chezmoiArguments init --force --no-tty --use-builtin-git=true $Repository
    if ($LASTEXITCODE -ne 0) { throw 'chezmoi init failed.' }

    $repositoryRoot = (chezmoi.exe @chezmoiArguments execute-template '{{ .chezmoi.workingTree }}').Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Could not locate the dotfiles repository.' }
    $configure = Join-Path $repositoryRoot 'system\windows\Configure.ps1'

    $step = 'Install Windows packages'
    Write-Host "==> $step"
    & $configure -Action Apply -Module packages
    if ($LASTEXITCODE -ne 0) { throw 'Installing Windows packages failed.' }
    Update-SessionPath
    $step = 'Apply Windows dotfiles'
    Write-Host "==> $step"
    chezmoi.exe @chezmoiArguments apply --force --no-tty
    if ($LASTEXITCODE -ne 0) { throw 'chezmoi apply failed.' }

    $step = 'Install configured runtimes and uv'
    Write-Host "==> $step"
    # Read the global configuration just applied by chezmoi, not a project mise.toml.
    Push-Location $env:USERPROFILE
    try {
        mise.exe install bun node uv
        if ($LASTEXITCODE -ne 0) { throw 'Installing mise runtimes failed.' }
        foreach ($command in 'bun', 'node', 'npm.cmd', 'uv') {
            mise.exe exec -- $command --version
            if ($LASTEXITCODE -ne 0) { throw "Verifying $command failed." }
        }
    } finally { Pop-Location }

    $step = 'Prepare Canopy'
    Write-Host "==> $step"
    & (Join-Path $repositoryRoot 'apps\yasb\Setup.ps1')

    $step = 'Apply Windows settings and startup'
    Write-Host "==> $step"
    & $configure -Action Apply -Module preferences, startup, privacy, graphics, debloat
    if ($LASTEXITCODE -ne 0) { throw 'Applying Windows configuration failed.' }

    $step = 'Provision Arch WSL'
    Write-Host "==> $step"
    & (Join-Path $repositoryRoot 'system\wsl\Setup.ps1') -Repository $Repository -LinuxUser $WslUser
    if ($LASTEXITCODE -eq 3010) {
        Write-Host 'Windows provisioning is complete. Arch Linux setup will continue after you restart and rerun setup.'
        exit 3010
    }
    if ($LASTEXITCODE -ne 0) { throw 'Configuring Arch Linux on WSL failed.' }
} catch {
    throw "Setup stopped at '$step': $($_.Exception.Message) Resolve the error above, then rerun the same bootstrap command. Completed steps can be safely reapplied; existing checkouts are not pulled or reset."
}

Write-Host 'Windows and Arch WSL provisioning and dotfile application are complete.'
Write-Host 'Review any warnings for unsupported removals or pending restarts; recheck those items after restarting.'
Write-Host 'Open a new terminal to pick up persistent environment changes.'
Write-Host 'Start the bar with apps\yasb\Start.ps1, or sign out and back in.'
