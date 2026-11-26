#requires -Version 7.0
[CmdletBinding()]
param([ValidateSet('Get', 'Test', 'Set')][string]$Operation = 'Test')

$ErrorActionPreference = 'Stop'
$command = Join-Path $env:LOCALAPPDATA 'Aside\CLI\current\aside.exe'
$installed = Test-Path -LiteralPath $command -PathType Leaf
if ($Operation -eq 'Get') { return @{ Installed = $installed; Command = $command } }
if ($Operation -eq 'Test') { return $installed }
if ($installed) { return }

$installer = Join-Path ([IO.Path]::GetTempPath()) ('aside-cli-' + [guid]::NewGuid().ToString('N') + '.ps1')
try {
    Invoke-WebRequest -Uri 'https://releases.aside.com/install.ps1' -OutFile $installer
    $signature = Get-AuthenticodeSignature -LiteralPath $installer
    $publisher = 'CN=AT YOUR SIDE INC, O=AT YOUR SIDE INC, L=San Francisco, S=California, C=US'
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -ne $publisher -or
        -not $signature.TimeStamperCertificate) {
        throw 'Aside CLI installer signature verification failed.'
    }
    & $installer
    if (-not (Test-Path -LiteralPath $command -PathType Leaf)) {
        throw "Aside CLI installer did not create $command."
    }
} finally {
    if (Test-Path -LiteralPath $installer) { Remove-Item -LiteralPath $installer }
}
