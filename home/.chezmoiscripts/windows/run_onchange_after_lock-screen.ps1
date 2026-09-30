$ErrorActionPreference = 'Stop'

# Windows Runtime projection requires Windows PowerShell's .NET Framework.
if ($PSVersionTable.PSEdition -ne 'Desktop') {
    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $PSCommandPath
    if ($LASTEXITCODE -ne 0) { throw 'Could not configure the Windows lock screen.' }
    return
}

$imagePath = (Get-Item -LiteralPath (Join-Path $env:USERPROFILE '.config\komorebi\wallpapers\wallhaven-oggvw9.jpg')).FullName
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType = WindowsRuntime] | Out-Null

if ([Windows.System.UserProfile.LockScreen]::OriginalImageFile.LocalPath -eq $imagePath) { return }

$asFileTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and
    $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
} | Select-Object -First 1

$operation = [Windows.Storage.StorageFile]::GetFileFromPathAsync($imagePath)
$fileTask = $asFileTask.MakeGenericMethod([Windows.Storage.StorageFile]).Invoke($null, @($operation))
if (-not $fileTask.Wait(30000)) { throw 'Timed out opening the lock screen image.' }
$file = $fileTask.GetAwaiter().GetResult()

$asActionTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and -not $_.IsGenericMethod -and
    $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction'
} | Select-Object -First 1
$operation = [Windows.System.UserProfile.LockScreen]::SetImageFileAsync($file)
$setTask = $asActionTask.Invoke($null, @($operation))
if (-not $setTask.Wait(30000)) { throw 'Timed out changing the Windows lock screen image.' }
$setTask.GetAwaiter().GetResult() | Out-Null
if ([Windows.System.UserProfile.LockScreen]::OriginalImageFile.LocalPath -ne $imagePath) {
    throw 'Windows did not retain the requested lock screen image.'
}
