[CmdletBinding()]
param(
    [string]$Repository = 'https://github.com/holybaechu/dotfiles.git',
    [ValidatePattern('^[a-z_][a-z0-9_-]{0,31}$')]
    [string]$WslUser = 'holybaechu'
)

$ErrorActionPreference = 'Stop'

function Update-SessionPath {
    foreach ($name in 'NVM_HOME', 'NVM_SYMLINK') {
        $value = [Environment]::GetEnvironmentVariable($name, 'User')
        if (-not $value) { $value = [Environment]::GetEnvironmentVariable($name, 'Machine') }
        if ($value) { [Environment]::SetEnvironmentVariable($name, $value, 'Process') }
    }
    $paths = @(
        $env:NVM_HOME
        $env:NVM_SYMLINK
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
    # Pass the script in memory so web bootstrap does not need a local file.
    $repositoryArgument = $Repository.Replace("'", "''")
    $command = "& {`n$($MyInvocation.MyCommand.ScriptBlock.ToString())`n} -Repository '$repositoryArgument' -WslUser '$WslUser'"
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    & $powerShell -NoLogo -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedCommand
    exit $LASTEXITCODE
}

if (-not (Get-Command chezmoi.exe -ErrorAction SilentlyContinue)) {
    winget.exe install --id twpayne.chezmoi --exact --source winget --accept-source-agreements --accept-package-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        throw "Installing chezmoi failed with exit code $LASTEXITCODE."
    }
    Update-SessionPath
}

chezmoi.exe init --force --no-tty --use-builtin-git=true $Repository
if ($LASTEXITCODE -ne 0) { throw 'chezmoi init failed.' }

$repositoryRoot = (chezmoi.exe execute-template '{{ .chezmoi.workingTree }}').Trim()
if ($LASTEXITCODE -ne 0) { throw 'Could not locate the dotfiles repository.' }
$configure = Join-Path $repositoryRoot 'system\windows\Configure.ps1'

& $configure -Action Apply -Module packages
if ($LASTEXITCODE -ne 0) { throw 'Installing Windows packages failed.' }
Update-SessionPath
bun --version
if ($LASTEXITCODE -ne 0) { throw 'Bun verification failed.' }
node.exe --version
if ($LASTEXITCODE -ne 0) { throw 'Node.js verification failed.' }
npm.cmd --version
if ($LASTEXITCODE -ne 0) { throw 'npm verification failed.' }
& (Join-Path $repositoryRoot 'apps\yasb\Setup.ps1')

chezmoi.exe apply --force --no-tty
if ($LASTEXITCODE -ne 0) { throw 'chezmoi apply failed.' }

& $configure -Action Apply -Module preferences
if ($LASTEXITCODE -ne 0) { throw 'Applying Windows preferences failed.' }
& $configure -Action Apply -Module startup
if ($LASTEXITCODE -ne 0) { throw 'Configuring Windows startup failed.' }
& $configure -Action Apply -Module privacy
if ($LASTEXITCODE -ne 0) { throw 'Applying Windows privacy settings failed.' }
& $configure -Action Apply -Module graphics
if ($LASTEXITCODE -ne 0) { throw 'Configuring Windows graphics failed.' }
& $configure -Action Apply -Module debloat
if ($LASTEXITCODE -ne 0) { throw 'Removing unwanted Windows apps failed.' }

& (Join-Path $repositoryRoot 'system\wsl\Setup.ps1') -Repository $Repository -LinuxUser $WslUser
if ($LASTEXITCODE -eq 3010) {
    Write-Host 'Windows provisioning is complete. Arch Linux setup will continue after you restart and rerun setup.'
    exit 3010
}
if ($LASTEXITCODE -ne 0) { throw 'Configuring Arch Linux on WSL failed.' }

Write-Host 'Windows and Arch WSL provisioning and dotfile application are complete.'
Write-Host 'Review any warnings for unsupported removals or pending restarts; recheck those items after restarting.'
Write-Host 'Open a new terminal to pick up persistent environment changes.'
Write-Host 'Start the bar with apps\yasb\Start.ps1, or sign out and back in.'
