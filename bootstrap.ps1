[CmdletBinding()]
param(
    [string]$Repository = 'https://github.com/holybaechu/dotfiles.git'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command winget.exe -CommandType Application -ErrorAction SilentlyContinue)) {
    throw 'WinGet is required. Install or update App Installer from Microsoft Store, then rerun bootstrap.ps1.'
}
$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run bootstrap.ps1 from a normal PowerShell window as your own user. Setup requests elevation for machine changes.'
}
if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64') {
    throw 'This bootstrap supports x64 Windows.'
}

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
if (-not (Get-Command mise.exe -CommandType Application -ErrorAction SilentlyContinue)) {
    winget.exe install --id jdx.mise --exact --source winget --accept-source-agreements --accept-package-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw "Installing mise failed with exit code $LASTEXITCODE." }
    Update-SessionPath
}
if ($PSVersionTable.PSVersion.Major -lt 7) {
    # Windows PowerShell is the entry point on a fresh Windows installation.
    mise.exe install powershell-core@latest
    if ($LASTEXITCODE -ne 0) { throw 'Installing PowerShell 7 through mise failed.' }
    $powerShellRoot = mise.exe where powershell-core@latest
    if ($LASTEXITCODE -ne 0) { throw 'Could not locate mise-managed PowerShell 7.' }
    $powerShell = Join-Path $powerShellRoot.Trim() 'pwsh.exe'
    if ($PSCommandPath) {
        & $powerShell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -Repository $Repository
        exit $LASTEXITCODE
    }
    # Pass the script in memory so web bootstrap does not need a local file.
    $repositoryArgument = $Repository.Replace("'", "''")
    $command = "& {`n$($MyInvocation.MyCommand.ScriptBlock.ToString())`n} -Repository '$repositoryArgument'"
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    & $powerShell -NoLogo -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedCommand
    exit $LASTEXITCODE
}

try {
    $step = 'Install chezmoi through mise'
    Write-Host "==> $step"
    mise.exe install chezmoi@latest
    if ($LASTEXITCODE -ne 0) { throw 'Installing chezmoi through mise failed.' }
    $chezmoiRoot = mise.exe where chezmoi@latest
    if ($LASTEXITCODE -ne 0) { throw 'Could not locate mise-managed chezmoi.' }
    $chezmoi = Join-Path $chezmoiRoot.Trim() 'chezmoi.exe'

    $step = 'Initialize the dotfiles checkout'
    Write-Host "==> $step"
    # A local invocation uses this checkout, including uncommitted edits. Web setup
    # uses chezmoi's configured source directory and preserves an existing checkout.
    $chezmoiArguments = @()
    if ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot '.chezmoiroot'))) {
        $chezmoiArguments = @('--source', $PSScriptRoot)
    }
    & $chezmoi @chezmoiArguments init --force --no-tty --use-builtin-git=true $Repository
    if ($LASTEXITCODE -ne 0) { throw 'chezmoi init failed.' }

    $repositoryRoot = (& $chezmoi @chezmoiArguments execute-template '{{ .chezmoi.workingTree }}').Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Could not locate the dotfiles repository.' }
    $configure = Join-Path $repositoryRoot 'system\windows\Configure.ps1'

    $step = 'Apply Windows dotfiles'
    Write-Host "==> $step"
    & $chezmoi @chezmoiArguments apply --force --no-tty
    if ($LASTEXITCODE -ne 0) { throw 'chezmoi apply failed.' }

    $step = 'Install configured mise tools'
    Write-Host "==> $step"
    # Read the global configuration just applied by chezmoi, not a project mise.toml.
    Push-Location $env:USERPROFILE
    try {
        mise.exe install
        if ($LASTEXITCODE -ne 0) { throw 'Installing configured mise tools failed.' }
        mise.exe reshim
        if ($LASTEXITCODE -ne 0) { throw 'Creating mise shims failed.' }
        # Startup programs and noninteractive shells also need stable tool paths.
        $miseData = if ($env:MISE_DATA_DIR) { $env:MISE_DATA_DIR } else { Join-Path $env:LOCALAPPDATA 'mise' }
        $shims = Join-Path $miseData 'shims'
        $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
        if ($shims -notin @($userPath -split ';')) {
            [Environment]::SetEnvironmentVariable('PATH', ($shims, $userPath -join ';'), 'User')
        }
        Update-SessionPath
        $miseEnvironment = mise.exe env --shell pwsh
        if ($LASTEXITCODE -ne 0) { throw 'Loading the mise environment failed.' }
        $miseEnvironment | Out-String | Invoke-Expression
        foreach ($command in 'bun', 'node', 'npm.cmd', 'git', 'clang') {
            mise.exe exec -- $command --version
            if ($LASTEXITCODE -ne 0) { throw "Verifying $command failed." }
        }
    } finally { Pop-Location }

    $step = 'Install Windows integrations'
    Write-Host "==> $step"
    & $configure -Action Apply -Module packages
    if ($LASTEXITCODE -ne 0) { throw 'Installing Windows integrations failed.' }
    Update-SessionPath

    $step = 'Start Flow Launcher'
    Write-Host "==> $step"
    Start-Process -FilePath (Join-Path $env:LOCALAPPDATA 'FlowLauncher\Flow.Launcher.exe') -WindowStyle Hidden

    $step = 'Apply Windows settings'
    Write-Host "==> $step"
    & $configure -Action Apply -Module preferences, privacy, graphics, debloat
    if ($LASTEXITCODE -ne 0) { throw 'Applying Windows configuration failed.' }

} catch {
    throw "Setup stopped at '$step': $($_.Exception.Message) Resolve the error above, then rerun the same bootstrap command. Completed steps can be safely reapplied; existing checkouts are not pulled or reset."
}

Write-Host 'Windows provisioning and dotfile application are complete.'
Write-Host 'Review any warnings for unsupported removals or pending restarts; recheck those items after restarting.'
Write-Host 'Open a new terminal to pick up persistent environment changes.'
Write-Host 'Flow Launcher starts at login; tap the left Windows key to open it (Win Hotkey plugin).'
