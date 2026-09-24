[CmdletBinding()]
param(
    [string]$Repository = 'https://github.com/holybaechu/dotfiles.git'
)

$ErrorActionPreference = 'Stop'

function Update-SessionPath {
    $paths = @(
        $env:PATH
        [Environment]::GetEnvironmentVariable('PATH', 'Machine')
        [Environment]::GetEnvironmentVariable('PATH', 'User')
    )
    $env:PATH = (($paths -join ';').Split(';') | Where-Object { $_ } | Select-Object -Unique) -join ';'
}

Update-SessionPath
if (-not (Get-Command chezmoi.exe -ErrorAction SilentlyContinue)) {
    winget.exe install --id twpayne.chezmoi --exact --source winget --accept-source-agreements --accept-package-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        throw "Installing chezmoi failed with exit code $LASTEXITCODE."
    }
    Update-SessionPath
}

chezmoi.exe init --use-builtin-git=true $Repository
if ($LASTEXITCODE -ne 0) { throw 'chezmoi init failed.' }

$repositoryRoot = (chezmoi.exe execute-template '{{ .chezmoi.workingTree }}').Trim()
if ($LASTEXITCODE -ne 0) { throw 'Could not locate the dotfiles repository.' }
$configure = Join-Path $repositoryRoot 'system\windows\Configure.ps1'

& $configure -Action Apply
Update-SessionPath
$env:KOMOREBI_CONFIG_HOME = [Environment]::GetEnvironmentVariable('KOMOREBI_CONFIG_HOME', 'User')

chezmoi.exe apply
if ($LASTEXITCODE -ne 0) { throw 'chezmoi apply failed.' }

Write-Host 'Windows provisioning and dotfile application are complete.'
Write-Host 'Open a new terminal to pick up persistent environment changes.'
