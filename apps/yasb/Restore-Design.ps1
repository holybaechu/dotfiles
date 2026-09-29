#requires -Version 7.0

[CmdletBinding(SupportsShouldProcess)]
param([string]$Checkpoint, [switch]$NoReload)

$ErrorActionPreference = 'Stop'
$backups = Join-Path $PSScriptRoot '.design-backups'
if (-not $Checkpoint) { $Checkpoint = (Get-Content -LiteralPath (Join-Path $backups 'latest.txt') -Raw).Trim() }
$saved = [IO.Path]::GetFullPath((Join-Path $backups $Checkpoint))
if (-not $saved.StartsWith($backups + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid checkpoint path.' }
$manifest = Get-Content -LiteralPath (Join-Path $saved 'manifest.json') -Raw | ConvertFrom-Json
$targets = foreach ($entry in $manifest.files) {
    $target = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $entry.path))
    if (-not $target.StartsWith($PSScriptRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid file path in checkpoint.' }
    $original = Join-Path (Join-Path $saved 'before') $entry.path
    if ($entry.existed -and -not (Test-Path -LiteralPath $original -PathType Leaf)) { throw "Missing backup: $original" }
    [pscustomobject]@{ entry = $entry; target = $target; original = $original }
}

if ($PSCmdlet.ShouldProcess($PSScriptRoot, "Restore $($targets.Count) design files from $Checkpoint")) {
    $rescue = Join-Path $saved ('undo-history\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
    foreach ($item in $targets) {
        if (Test-Path -LiteralPath $item.target -PathType Leaf) {
            $copy = Join-Path $rescue $item.entry.path
            [IO.Directory]::CreateDirectory((Split-Path $copy)) | Out-Null
            Copy-Item -LiteralPath $item.target -Destination $copy
        }
    }
    foreach ($item in $targets) {
        if ($item.entry.existed) {
            [IO.Directory]::CreateDirectory((Split-Path $item.target)) | Out-Null
            Copy-Item -LiteralPath $item.original -Destination $item.target -Force
        }
        elseif (Test-Path -LiteralPath $item.target -PathType Leaf) {
            Remove-Item -LiteralPath $item.target
        }
    }
    Write-Host "Previous design restored. Copies of the replaced files are in $rescue"
    if (-not $NoReload) {
        & (Join-Path $PSScriptRoot '.venv\Scripts\python.exe') (Join-Path $PSScriptRoot 'launch.py') --reload
    }
}
