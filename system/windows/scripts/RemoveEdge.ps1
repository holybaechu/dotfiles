#requires -Version 5.1

[CmdletBinding()]
param([ValidateSet('Get', 'Test', 'Set')][string]$Operation = 'Test')

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') {
    throw 'Run this through Configure.ps1 -Module debloat, or Windows PowerShell 5.1 as administrator.'
}

$edgeExecutable = Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'
$edgeRegistration = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge'
function Get-EdgeState {
    [pscustomobject]@{
        ExecutableExists = Test-Path -LiteralPath $edgeExecutable
        Registered = Test-Path -LiteralPath $edgeRegistration
        Packages = @(Get-AppxPackage -AllUsers -Name Microsoft.MicrosoftEdge.Stable -ErrorAction Stop)
    }
}
function Test-EdgeAbsent($State) {
    -not $State.ExecutableExists -and -not $State.Registered -and $State.Packages.Count -eq 0
}

$state = Get-EdgeState
switch ($Operation) {
    Get {
        $state | Select-Object ExecutableExists, Registered, @{Name='Packages'; Expression={@($_.Packages.PackageFullName)}}
    }
    Test { Test-EdgeAbsent $state }
    Set {
        if (Test-EdgeAbsent $state) { return }
        if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64') { throw 'The pinned Edge remover supports x64 Windows only.' }

        # Removal step from https://github.com/ShadowWhisperer/Remove-MS-Edge.
        # Pin the Microsoft-signed installer and verify it before running elevated.
        $revision = 'ad8d59b28d742e117be7585b534745ee40efb599'
        $expectedHash = '0950336e0d633eb645e0cf66780d2102a182caa184264d4f62146fe229f636e7'
        $cache = Join-Path $env:ProgramData 'dotfiles\tools\remove-edge'
        $installer = Join-Path $cache 'setup.exe'
        New-Item -ItemType Directory -Path $cache -Force | Out-Null
        if (-not (Test-Path -LiteralPath $installer)) {
            Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/ShadowWhisperer/Remove-MS-Edge/$revision/_Source/setup.x64.exe" -OutFile $installer
        }
        if ((Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash -ne $expectedHash) {
            throw 'The Edge remover checksum does not match the pinned upstream installer.'
        }
        if ((Get-AuthenticodeSignature -LiteralPath $installer).Status -ne 'Valid') {
            throw 'The Edge remover does not have a valid Microsoft installer signature.'
        }

        Write-Warning 'Upstream warns that some Windows updates may require reinstalling Edge first. Recovery: https://www.microsoft.com/edge/download'
        $process = Start-Process -FilePath $installer -ArgumentList '--uninstall', '--system-level', '--force-uninstall', '--verbose-logging' -WindowStyle Hidden -Wait -PassThru

        # Remove the remaining browser registration through Appx, if present.
        # The shared WebView runtime and system DevTools package are separate.
        foreach ($package in @(Get-AppxPackage -AllUsers -Name Microsoft.MicrosoftEdge.Stable -ErrorAction Stop)) {
            if ($package.NonRemovable) { throw 'The remaining Edge browser package is marked non-removable.' }
            Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop
        }
        if (-not (Test-EdgeAbsent (Get-EdgeState))) {
            throw "Edge remains installed after the upstream remover (installer exit code $($process.ExitCode))."
        }
    }
}
