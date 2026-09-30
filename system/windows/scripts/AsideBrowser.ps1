#requires -Version 7.0

[CmdletBinding()]
param([ValidateSet('Get', 'Test', 'Set')][string]$Operation = 'Test')

$ErrorActionPreference = 'Stop'

function Get-AsideInstallation {
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Aside'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Aside'
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Aside'
    )
    foreach ($key in $keys) {
        if (-not (Test-Path -LiteralPath $key)) { continue }
        $app = Get-ItemProperty -LiteralPath $key
        if ($app.DisplayName -eq 'Aside' -and $app.InstallLocation -and
                (Test-Path -LiteralPath (Join-Path $app.InstallLocation 'Aside.exe') -PathType Leaf)) {
            return $app
        }
    }
}

$current = Get-AsideInstallation
switch ($Operation) {
    Get { @{ installed = $null -ne $current; version = $current.DisplayVersion } }
    Test { $null -ne $current }
    Set {
        if ($null -ne $current) { return }
        # Aside's Windows download currently distributes an x64 installer.
        if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64') {
            throw 'Aside bootstrap currently supports x64 Windows only.'
        }

        $installer = Join-Path ([IO.Path]::GetTempPath()) ('Aside-' + [guid]::NewGuid().ToString('N') + '.exe')
        try {
            Invoke-WebRequest -Uri 'https://aside.com/api/download/windows' -OutFile $installer
            $signature = Get-AuthenticodeSignature -LiteralPath $installer
            if ($signature.Status -ne 'Valid' -or
                    $signature.SignerCertificate.Subject -notmatch '(?i)(^|,\s*)CN=AT YOUR SIDE INC(,|$)') {
                throw 'The Aside installer does not have a valid AT YOUR SIDE INC signature.'
            }

            # The official tagged Chromium metainstaller installs Aside and its updater.
            # Silent mode also suppresses the browser launch after installation.
            $process = Start-Process -FilePath $installer -ArgumentList '--silent', '--system' -WindowStyle Hidden -Wait -PassThru
            if ($process.ExitCode -ne 0) {
                throw "Installing Aside failed with exit code $($process.ExitCode)."
            }
            if ($null -eq (Get-AsideInstallation)) {
                throw 'Aside installation finished, but its registered browser executable was not found.'
            }
        } finally {
            if (Test-Path -LiteralPath $installer) { Remove-Item -LiteralPath $installer -Force }
        }
    }
}
