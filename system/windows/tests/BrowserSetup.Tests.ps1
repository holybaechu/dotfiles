#requires -Version 7.0
# Machine interactions are mocked; files are written only in a temporary fixture.
$ErrorActionPreference = 'Stop'
$scripts = Join-Path (Split-Path $PSScriptRoot) 'scripts'
$global:BrowserFixture = @{
    Registry = @{}; Writes = 0; Deny = $false; Drop = $false; Downloads = 0; Launches = 0
    Signature = 'Valid'; Signer = 'AT YOUR SIDE INC'; ExitCode = 0; Register = $true
    Running = $false; FileWrites = 0; FileDeny = $false; FileDrop = $false
}
$originalLocalAppData = $env:LOCALAPPDATA
$originalUserProfile = $env:USERPROFILE
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-browser-' + [guid]::NewGuid().ToString('N'))
$appKey = 'HKLM:\Software\WOW6432Node\Aside\Update\Clients\{822e45a2-1677-4f9e-8052-23cf82713869}'
function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Assert-Failure([scriptblock]$Action, [string]$Expected) {
    $message = ''
    try { & $Action } catch { $message = $_.Exception.Message }
    Assert ($message -like "*$Expected*") "Expected '$Expected'; got '$message'."
}
function Test-Path {
    [CmdletBinding()]param([string]$LiteralPath)
    if ($LiteralPath -match '^HK(CU|LM):') { return $global:BrowserFixture.Registry.ContainsKey($LiteralPath) }
    Microsoft.PowerShell.Management\Test-Path -LiteralPath $LiteralPath
}
function Get-ItemProperty {
    [CmdletBinding()]param([string]$LiteralPath)
    [pscustomobject]$global:BrowserFixture.Registry[$LiteralPath]
}
function Get-Item {
    [CmdletBinding()]param([string]$LiteralPath)
    $item = [pscustomobject]@{ Data = $global:BrowserFixture.Registry[$LiteralPath] }
    $item | Add-Member ScriptMethod GetValueNames { @($this.Data.Keys) }
    $item | Add-Member ScriptMethod GetValueKind { param($name) $this.Data[$name].Kind }
    $item | Add-Member ScriptMethod GetValue { param($name,$default,$options) $this.Data[$name].Value }
    $item
}
function New-Item {
    [CmdletBinding()]param([string]$Path,[switch]$Force)
    Assert ($Path -in @(
        'HKLM:\Software\WOW6432Node\Google\Chrome\Extensions\aeblfdkhhhdcdjpifhhbdiojplfjncoa'
        'HKLM:\Software\WOW6432Node\Google\Chrome\Extensions\ddkjiahejlhfcafbddmgiahcphecmpfh'
    )) 'Only the 1Password and uBlock Origin Lite Web Store registrations may be created.'
    $global:BrowserFixture.Registry[$Path] = @{}
}
function New-ItemProperty {
    [CmdletBinding()]param([string]$LiteralPath,[string]$Name,$Value,[string]$PropertyType,[switch]$Force)
    if ($global:BrowserFixture.Deny) { throw 'Registry access denied.' }
    $global:BrowserFixture.Writes++
    if (-not $global:BrowserFixture.Drop) { $global:BrowserFixture.Registry[$LiteralPath][$Name] = @{ Value = $Value; Kind = $PropertyType } }
}
function Invoke-WebRequest {
    [CmdletBinding()]param([string]$Uri,[string]$OutFile)
    Assert ($Uri -eq 'https://aside.com/api/download/windows?arch=x64') 'Only the official Aside installer may be downloaded.'
    $global:BrowserFixture.Downloads++
    [IO.File]::WriteAllText($OutFile, 'mock installer')
}
function Get-AuthenticodeSignature {
    [CmdletBinding()]param([string]$LiteralPath)
    $certificate = [pscustomobject]@{}
    $certificate | Add-Member ScriptMethod GetNameInfo { param($type,$issuer) $global:BrowserFixture.Signer }
    @{ Status = $global:BrowserFixture.Signature; SignerCertificate = $certificate }
}
function Start-Process {
    [CmdletBinding()]param([string]$FilePath,[string[]]$ArgumentList,[string]$WindowStyle,[switch]$Wait,[switch]$PassThru)
    $global:BrowserFixture.Launches++
    if ($global:BrowserFixture.ExitCode -eq 0 -and $global:BrowserFixture.Register) {
        $global:BrowserFixture.Registry[$appKey] = @{ pv = '1.0.1022.1' }
    }
    $process = [pscustomobject]@{ ExitCode = $global:BrowserFixture.ExitCode }
    $process | Add-Member ScriptMethod Dispose { }
    $process
}
function Get-Process {
    [CmdletBinding()]param([string[]]$Name)
    if ($global:BrowserFixture.Running) { [pscustomobject]@{ ProcessName = 'Aside' } }
}
function Set-Content {
    [CmdletBinding()]param([string]$LiteralPath,[Parameter(ValueFromPipeline)]$Value,[string]$Encoding)
    process {
        if ($global:BrowserFixture.FileDeny) { throw 'File access denied.' }
        $global:BrowserFixture.FileWrites++
        if (-not $global:BrowserFixture.FileDrop) {
            Microsoft.PowerShell.Management\Set-Content -LiteralPath $LiteralPath -Value $Value -Encoding $Encoding
        }
    }
}
try {
    $aside = Join-Path $scripts 'Aside.ps1'
    Assert (-not (& $aside -Operation Get).Installed -and -not (& $aside -Operation Test)) 'An absent browser must not pass detection.'
    Assert ($global:BrowserFixture.Downloads -eq 0) 'Get and Test must not download or install anything.'
    & $aside -Operation Set
    Assert (& $aside -Operation Test) 'A successful browser installation must be detected.'
    & $aside -Operation Set
    Assert ($global:BrowserFixture.Downloads -eq 1 -and $global:BrowserFixture.Launches -eq 1) 'Reapply must keep an existing browser.'
    $global:BrowserFixture.Registry.Remove($appKey)
    $global:BrowserFixture.Signature = 'NotSigned'
    Assert-Failure { & $aside -Operation Set } 'valid AT YOUR SIDE INC signature'
    Assert ($global:BrowserFixture.Launches -eq 1) 'An invalid installer must never run.'
    $global:BrowserFixture.Signature = 'Valid'; $global:BrowserFixture.ExitCode = 5
    Assert-Failure { & $aside -Operation Set } 'exit code 5'
    $global:BrowserFixture.ExitCode = 0; $global:BrowserFixture.Register = $false
    Assert-Failure { & $aside -Operation Set } 'without registering the browser'

    $extension = Join-Path $scripts 'BrowserExtension.ps1'
    $extensions = @{
        '1Password' = 'aeblfdkhhhdcdjpifhhbdiojplfjncoa'
        uBlockOriginLite = 'ddkjiahejlhfcafbddmgiahcphecmpfh'
    }
    foreach ($name in $extensions.Keys) {
        Assert (-not (& $extension -Operation Get -Extension $name).Exists -and -not (& $extension -Operation Test -Extension $name)) 'An absent extension registration must not pass detection.'
        & $extension -Operation Set -Extension $name
        Assert (& $extension -Operation Test -Extension $name) 'Extension registration must converge.'
        $writes = $global:BrowserFixture.Writes
        & $extension -Operation Set -Extension $name
        Assert ($global:BrowserFixture.Writes -eq $writes) 'Matching registration must not be rewritten.'
        $extensionKey = "HKLM:\Software\WOW6432Node\Google\Chrome\Extensions\$($extensions[$name])"
        $global:BrowserFixture.Registry[$extensionKey].update_url.Value = 'wrong'
        $global:BrowserFixture.Deny = $true
        Assert-Failure { & $extension -Operation Set -Extension $name } 'Registry access denied'
        $global:BrowserFixture.Deny = $false; $global:BrowserFixture.Drop = $true
        Assert-Failure { & $extension -Operation Set -Extension $name } 'did not retain'
        $global:BrowserFixture.Drop = $false
    }

    $preferences = Join-Path $scripts 'AsidePreferences.ps1'
    $env:LOCALAPPDATA = Join-Path $fixtureRoot 'Local'
    $env:USERPROFILE = Join-Path $fixtureRoot 'User'
    Assert (-not (& $preferences -Operation Test)) 'Uninitialized Aside must require first-run setup.'
    Assert ((& $preferences -Operation Get).PendingFiles.Count -eq 0) 'Get must not invent pending paths for absent profiles.'
    Assert-Failure { & $preferences -Operation Set } 'Launch Aside and sign in once'
    Assert (-not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $fixtureRoot)) 'Detection must not create browser or vault accounts.'

    $profile = Join-Path $env:LOCALAPPDATA 'Aside\User Data\Default'
    $account = Join-Path $env:USERPROFILE '.aside\password-manager\accounts\fixture'
    foreach ($directory in @($profile, $account)) {
        [void][IO.Directory]::CreateDirectory($directory)
    }
    [IO.File]::WriteAllText("$profile\Preferences", '{}')
    [IO.File]::WriteAllText("$account\settings.json", '{"useBuiltinPasswordManager":true,"autoLockTimeout":60}')
    $global:BrowserFixture.Running = $true
    Assert-Failure { & $preferences -Operation Set } 'Quit Aside'
    Assert ($global:BrowserFixture.FileWrites -eq 0) 'A running browser must prevent all preference writes.'
    $global:BrowserFixture.Running = $false; $global:BrowserFixture.FileDeny = $true
    Assert-Failure { & $preferences -Operation Set } 'File access denied'
    $global:BrowserFixture.FileDeny = $false; $global:BrowserFixture.FileDrop = $true
    Assert-Failure { & $preferences -Operation Set } 'did not retain'
    $global:BrowserFixture.FileDrop = $false
    & $preferences -Operation Set
    Assert (& $preferences -Operation Test) 'Aside password-manager settings must converge.'
    $saved = Get-Content -LiteralPath "$account\settings.json" -Raw | ConvertFrom-Json
    Assert ($saved.useBuiltinPasswordManager -ceq $false -and $saved.autoLockTimeout -eq 60) 'Disable Aside Vault while preserving its other settings.'
    $writes = $global:BrowserFixture.FileWrites
    & $preferences -Operation Set
    Assert ($global:BrowserFixture.FileWrites -eq $writes) 'Matching preferences must not be rewritten.'
    [IO.File]::WriteAllText("$account\settings.json", '[]')
    Assert-Failure { & $preferences -Operation Set } 'Expected a JSON object'
    Assert ($global:BrowserFixture.FileWrites -eq $writes) 'Invalid metadata must fail before any settings are written.'
    Write-Output 'PASS: browser setup, installer failures, denied/ignored writes and safe Aside preference reapply'
} finally {
    $env:LOCALAPPDATA = $originalLocalAppData
    $env:USERPROFILE = $originalUserProfile
    $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
    if (-not $resolvedFixture.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture cleanup escaped the temporary directory.' }
    if (Microsoft.PowerShell.Management\Test-Path -LiteralPath $resolvedFixture) { Remove-Item -LiteralPath $resolvedFixture -Recurse -Force }
    Remove-Variable BrowserFixture -Scope Global
}
