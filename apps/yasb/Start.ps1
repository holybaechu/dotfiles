[CmdletBinding()]
param([switch]$Preview)

$ErrorActionPreference = 'Stop'
$python = Join-Path $PSScriptRoot '.venv\Scripts\pythonw.exe'
$launcher = Join-Path $PSScriptRoot 'launch.py'
if (-not (Test-Path -LiteralPath $python)) {
    throw 'Run apps\yasb\Setup.ps1 first.'
}
$arguments = @('"' + $launcher + '"')
if ($Preview) { $arguments += '--preview' }
Start-Process -FilePath $python -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -WindowStyle Hidden
