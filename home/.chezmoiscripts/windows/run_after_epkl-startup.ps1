$ErrorActionPreference = 'Stop'

$executable = Join-Path $env:LOCALAPPDATA 'EPKL\EPKL.exe'
if (-not (Test-Path -LiteralPath $executable)) {
    throw 'EPKL.exe is missing. Reapply the dotfiles to download the EPKL archive.'
}
$workingDirectory = Split-Path $executable
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Startup')) 'EPKL.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
if ($shortcut.TargetPath -ne $executable -or $shortcut.WorkingDirectory -ne $workingDirectory) {
    $shortcut.TargetPath = $executable
    $shortcut.WorkingDirectory = $workingDirectory
    $shortcut.Save()
}
$saved = $shell.CreateShortcut($shortcutPath)
if (-not (Test-Path -LiteralPath $shortcutPath) -or
    $saved.TargetPath -ne $executable -or $saved.WorkingDirectory -ne $workingDirectory) {
    throw 'Windows did not retain the EPKL startup shortcut.'
}
