#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Get', 'Test', 'Set')][string]$Operation = 'Test'
)
$ErrorActionPreference = 'Stop'

$productKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{BD599184-FA54-4079-A18A-68CB39609A77}'
$profileKey = 'HKLM:\SOFTWARE\Microsoft\CTF\TIP\{5CC2EDB1-F5F4-456C-A871-CF6B62415CD9}\LanguageProfile\0x00000412\{36207E64-3175-433E-A713-2D0F7473273A}'
$installed = (Test-Path -LiteralPath $productKey) -and (Test-Path -LiteralPath $profileKey) -and
    (Test-Path -LiteralPath (Join-Path $env:ProgramFiles 'YmSoft\NgsEdit\NgsEdit.exe')) -and
    (Test-Path -LiteralPath (Join-Path $env:SystemRoot 'System32\NgsIme.ime'))
if ($Operation -eq 'Get') { return @{ Installed = $installed; Version = '11.01' } }
if ($Operation -eq 'Test') { return $installed }
if ($installed) { return }

$installer = Join-Path ([IO.Path]::GetTempPath()) ('Nalgaeset-' + [guid]::NewGuid().ToString('N') + '.msi')
$log = "$installer.log"
try {
    Invoke-WebRequest -Uri 'https://smlooking4u.mycafe24.com/bin/Ngs1101Setup_x64.msi' -OutFile $installer
    if ((Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash -ne '426002601e87ec46b6a56425db42cd4f5b7afaf7998e460cc4b2f1510a820367') {
        throw 'The Nalgaeset installer checksum does not match the pinned 11.01 release.'
    }
    $process = Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/i `"$installer`" /qn /norestart ALLUSERS=1 /L*v `"$log`"" -WindowStyle Hidden -Wait -PassThru
    try {
        if ($process.ExitCode -notin @(0, 3010)) { throw "Nalgaeset installation failed with exit code $($process.ExitCode). See $log." }
        if ($process.ExitCode -eq 3010) { Write-Warning 'Restart Windows to finish installing Nalgaeset.' }
    } finally { $process.Dispose() }
    if (-not (& $PSCommandPath -Operation Test)) {
        throw "Nalgaeset finished installing without registering its Korean input profile. See $log."
    }
    if (Test-Path -LiteralPath $log) { Remove-Item -LiteralPath $log -Force }
} finally {
    if (Test-Path -LiteralPath $installer) { Remove-Item -LiteralPath $installer -Force }
}
