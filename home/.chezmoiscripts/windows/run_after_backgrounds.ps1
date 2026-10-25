$ErrorActionPreference = 'Stop'

# Windows Runtime projection requires Windows PowerShell's .NET Framework.
if ($PSVersionTable.PSEdition -ne 'Desktop') {
    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $PSCommandPath
    if ($LASTEXITCODE -ne 0) { throw 'Could not configure the Windows desktop and lock screen.' }
    return
}

$imagePath = (Get-Item -LiteralPath (Join-Path $env:USERPROFILE '.config\wallpapers\wallhaven-oggvw9.jpg')).FullName
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType = WindowsRuntime] | Out-Null
if (-not ('DotfilesWallpaper' -as [type])) {
    Add-Type @'
using System.Runtime.InteropServices;
public static class DotfilesWallpaper {
    [DllImport("user32.dll", EntryPoint = "SystemParametersInfoW", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool SetWallpaper(uint action, uint param, string path, uint flags);
}
'@
}

$asFileTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and
    $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
} | Select-Object -First 1

$operation = [Windows.Storage.StorageFile]::GetFileFromPathAsync($imagePath)
$fileTask = $asFileTask.MakeGenericMethod([Windows.Storage.StorageFile]).Invoke($null, @($operation))
if (-not $fileTask.Wait(30000)) { throw 'Timed out opening the background image.' }
$file = $fileTask.GetAwaiter().GetResult()

# Select a fixed picture so Windows Spotlight does not replace either image.
$wallpaperKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers'
$contentKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
foreach ($key in @($wallpaperKey, $contentKey)) {
    if (-not (Test-Path -LiteralPath $key)) { New-Item -Path $key -Force | Out-Null }
}
New-ItemProperty -LiteralPath $wallpaperKey -Name BackgroundType -Value 0 -PropertyType DWord -Force | Out-Null
New-ItemProperty -LiteralPath $contentKey -Name RotatingLockScreenEnabled -Value 0 -PropertyType DWord -Force | Out-Null

if ((Get-ItemProperty -LiteralPath 'HKCU:\Control Panel\Desktop').WallPaper -ne $imagePath) {
    # SPI_SETDESKWALLPAPER with SPIF_UPDATEINIFILE | SPIF_SENDCHANGE.
    if (-not [DotfilesWallpaper]::SetWallpaper(20, 0, $imagePath, 3)) {
        throw [ComponentModel.Win32Exception]::new([Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
}
if ([Windows.System.UserProfile.LockScreen]::OriginalImageFile.LocalPath -ne $imagePath) {
    $asActionTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and -not $_.IsGenericMethod -and
        $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction'
    } | Select-Object -First 1
    $operation = [Windows.System.UserProfile.LockScreen]::SetImageFileAsync($file)
    $setTask = $asActionTask.Invoke($null, @($operation))
    if (-not $setTask.Wait(30000)) { throw 'Timed out changing the lock screen image.' }
    $setTask.GetAwaiter().GetResult() | Out-Null
}
if ((Get-ItemProperty -LiteralPath 'HKCU:\Control Panel\Desktop').WallPaper -ne $imagePath) {
    throw 'Windows did not retain the requested desktop wallpaper.'
}
if ([Windows.System.UserProfile.LockScreen]::OriginalImageFile.LocalPath -ne $imagePath) {
    throw 'Windows did not retain the requested lock screen image.'
}
