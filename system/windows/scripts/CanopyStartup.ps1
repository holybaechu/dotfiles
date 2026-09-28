[CmdletBinding()]
param([ValidateSet('Get', 'Test', 'Set')][string]$Operation = 'Test')

$ErrorActionPreference = 'Stop'
$repository = Split-Path (Split-Path (Split-Path $PSScriptRoot))
$runtime = Join-Path $repository 'apps\yasb'
$python = Join-Path $runtime '.venv\Scripts\pythonw.exe'
$arguments = '"' + (Join-Path $runtime 'launch.py') + '"'
$startup = [Environment]::GetFolderPath('Startup')
$path = Join-Path $startup 'Canopy.lnk'
$legacy = Join-Path $startup 'Zebar.lnk'
$shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($path)

switch ($Operation) {
    Get { @{ target = $shortcut.TargetPath; arguments = $shortcut.Arguments } }
    Test {
        (Test-Path -LiteralPath $python) -and
        $shortcut.TargetPath -eq $python -and
        $shortcut.Arguments -eq $arguments -and
        $shortcut.WorkingDirectory -eq $runtime -and
        -not (Test-Path -LiteralPath $legacy)
    }
    Set {
        if (-not (Test-Path -LiteralPath $python)) { throw 'Run apps\yasb\Setup.ps1 before applying startup.' }
        $shortcut.TargetPath = $python
        $shortcut.Arguments = $arguments
        $shortcut.WorkingDirectory = $runtime
        $shortcut.Save()
        if (Test-Path -LiteralPath $legacy) { Remove-Item -LiteralPath $legacy }
    }
}
