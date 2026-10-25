#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Get', 'Test', 'Set')][string]$Operation = 'Test'
)
$ErrorActionPreference = 'Stop'

# Aside's signed installer registers the browser with its Chromium updater.
$appId = '{822e45a2-1677-4f9e-8052-23cf82713869}'
$installed = @(foreach ($key in @(
    "HKLM:\Software\WOW6432Node\Aside\Update\Clients\$appId"
    "HKCU:\Software\Aside\Update\Clients\$appId"
)) {
    if (Test-Path -LiteralPath $key) {
        $app = Get-ItemProperty -LiteralPath $key
        if ($app.pv -and $app.pv -ne '0.0.0.0') {
            [pscustomobject]@{ Version = $app.pv; RegistryKey = $key }
        }
    }
})
if ($Operation -eq 'Get') { return @{ Installed = $installed.Count -gt 0; Registrations = $installed } }
if ($Operation -eq 'Test') { return $installed.Count -gt 0 }
if ($installed.Count) { return }

$installer = Join-Path ([IO.Path]::GetTempPath()) ('AsideInstaller-' + [guid]::NewGuid().ToString('N') + '.exe')
try {
    # This is the x64 download redirect used by https://aside.com/download.
    Invoke-WebRequest -Uri 'https://aside.com/api/download/windows?arch=x64' -OutFile $installer
    $signature = Get-AuthenticodeSignature -LiteralPath $installer
    if ($signature.Status -ne 'Valid' -or
        $signature.SignerCertificate.GetNameInfo('SimpleName', $false) -ne 'AT YOUR SIDE INC') {
        throw 'Aside installer does not have a valid AT YOUR SIDE INC signature.'
    }
    $tag = "appguid=$appId&appname=Aside&needsadmin=true&usagestats=0"
    $process = Start-Process -FilePath $installer -ArgumentList "--install=$tag", '--silent' -WindowStyle Hidden -Wait -PassThru
    try {
        if ($process.ExitCode -ne 0) { throw "Aside installation failed with exit code $($process.ExitCode)." }
    } finally { $process.Dispose() }
    if (-not (& $PSCommandPath -Operation Test)) {
        throw 'Aside installer finished without registering the browser. Rerun the packages module after resolving the installer error.'
    }
} finally {
    if (Test-Path -LiteralPath $installer) { Remove-Item -LiteralPath $installer -Force }
}
