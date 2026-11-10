#requires -Version 7.0

param(
    [ValidateSet('Get', 'Test', 'Set')][string]$Operation = 'Get'
)

$ErrorActionPreference = 'Stop'
$shell = New-Object -ComObject Shell.Application
# ssfBITBUCKET and the Quick access shell folder; independent of the display language.
$recycleBin = $shell.Namespace(10)
$quickAccess = $shell.Namespace('shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}')
if ($null -eq $recycleBin -or $null -eq $quickAccess) {
    throw 'Recycle Bin or Quick access is unavailable. Run preferences from your Windows desktop session.'
}

function Test-RecycleBinPinned {
    @($quickAccess.Items() | Where-Object {
        $_.Path -eq $recycleBin.Self.Path -and $_.ExtendedProperty('System.Home.IsPinned')
    }).Count -gt 0
}

if ($Operation -ne 'Set') { return Test-RecycleBinPinned }
if (Test-RecycleBinPinned) { return }

$recycleBin.Self.InvokeVerb('pintohome')
# Explorer may update the pin asynchronously. Verify it before reporting success.
for ($attempt = 0; $attempt -lt 20; $attempt++) {
    if (Test-RecycleBinPinned) { return }
    Start-Sleep -Milliseconds 250
}
throw 'Windows did not retain the Recycle Bin pin in Quick access.'
